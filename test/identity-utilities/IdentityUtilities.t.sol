// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import { ClaimIssuerHelper } from "../helpers/ClaimIssuerHelper.sol";
import { ClaimSignerHelper } from "../helpers/ClaimSignerHelper.sol";
import { IdentityHelper } from "../helpers/IdentityHelper.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { ClaimIssuer } from "contracts/ClaimIssuer.sol";
import { Identity } from "contracts/Identity.sol";
import { IdentityUtilities } from "contracts/IdentityUtilities.sol";
import { IIdentityUtilities } from "contracts/interface/IIdentityUtilities.sol";
import { KeyPurposes } from "contracts/libraries/KeyPurposes.sol";
import { KeyTypes } from "contracts/libraries/KeyTypes.sol";
import { IdentityUtilitiesProxy } from "contracts/proxy/IdentityUtilitiesProxy.sol";
import { Test } from "forge-std/Test.sol";
import { Test as TestContract } from "test/mocks/Test.sol";
import { TestIdentityUtilities } from "test/mocks/TestIdentityUtilities.sol";

/// @notice Test suite for IdentityUtilities topic schema registry
contract IdentityUtilitiesTest is Test {

    IdentityUtilities internal utilities;
    address internal admin;
    uint256 internal adminPk;
    address internal user;

    function setUp() public {
        (admin, adminPk) = makeAddrAndKey("utilAdmin");
        user = makeAddr("utilUser");

        IdentityUtilities impl = new IdentityUtilities();
        IdentityUtilitiesProxy proxy =
            new IdentityUtilitiesProxy(address(impl), abi.encodeCall(IdentityUtilities.initialize, (admin)));
        utilities = IdentityUtilities(address(proxy));
    }

    // ---- internal helpers ----

    function _encodeNames(string[] memory names) internal pure returns (bytes memory) {
        return abi.encode(names);
    }

    function _encodeTypes(string[] memory types) internal pure returns (bytes memory) {
        return abi.encode(types);
    }

    function _singleStringArray(string memory s) internal pure returns (string[] memory arr) {
        arr = new string[](1);
        arr[0] = s;
    }

    function _addDefaultTopic(
        uint256 topicId,
        string memory name,
        string[] memory fieldNames,
        string[] memory fieldTypes
    ) internal {
        vm.prank(admin);
        utilities.addTopic(topicId, name, _encodeNames(fieldNames), _encodeTypes(fieldTypes));
    }

    // =========================================================================
    //  Topic schema examples from AssetID spec
    // =========================================================================

    function test_addAndRetrieveNAVPerShare() public {
        uint256 topicId = 1000003;
        string[] memory fieldNames = new string[](3);
        fieldNames[0] = "value";
        fieldNames[1] = "decimals";
        fieldNames[2] = "timestamp";
        string[] memory fieldTypes = new string[](3);
        fieldTypes[0] = "uint256";
        fieldTypes[1] = "uint256";
        fieldTypes[2] = "uint256";

        bytes memory encodedNames = _encodeNames(fieldNames);
        bytes memory encodedTypes = _encodeTypes(fieldTypes);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true, address(utilities));
        emit IIdentityUtilities.TopicAdded(topicId, "NAV Per Share", encodedNames, encodedTypes);
        utilities.addTopic(topicId, "NAV Per Share", encodedNames, encodedTypes);

        (string[] memory retNames, string[] memory retTypes) = utilities.getSchema(topicId);
        assertEq(retNames.length, 3);
        assertEq(retNames[0], "value");
        assertEq(retNames[1], "decimals");
        assertEq(retNames[2], "timestamp");
        assertEq(retTypes[0], "uint256");
        assertEq(retTypes[1], "uint256");
        assertEq(retTypes[2], "uint256");
    }

    function test_addISIN() public {
        bytes memory encodedNames = _encodeNames(_singleStringArray("isin"));
        bytes memory encodedTypes = _encodeTypes(_singleStringArray("string"));

        vm.prank(admin);
        utilities.addTopic(1000001, "ISIN", encodedNames, encodedTypes);

        (string[] memory retNames, string[] memory retTypes) = utilities.getSchema(1000001);
        assertEq(retNames[0], "isin");
        assertEq(retTypes[0], "string");
    }

    function test_addLEI() public {
        _addDefaultTopic(1000002, "LEI", _singleStringArray("lei"), _singleStringArray("string"));

        (string[] memory retNames, string[] memory retTypes) = utilities.getSchema(1000002);
        assertEq(retNames[0], "lei");
        assertEq(retTypes[0], "string");
    }

    function test_addNAVGlobal() public {
        string[] memory fieldNames = new string[](3);
        fieldNames[0] = "value";
        fieldNames[1] = "decimals";
        fieldNames[2] = "timestamp";
        string[] memory fieldTypes = new string[](3);
        fieldTypes[0] = "uint256";
        fieldTypes[1] = "uint256";
        fieldTypes[2] = "uint256";

        _addDefaultTopic(1000004, "NAV Global", fieldNames, fieldTypes);

        (string[] memory retNames, string[] memory retTypes) = utilities.getSchema(1000004);
        assertEq(retNames.length, 3);
        assertEq(retNames[0], "value");
        assertEq(retTypes[2], "uint256");
    }

    function test_addBaseCurrency() public {
        _addDefaultTopic(1000005, "Base Currency", _singleStringArray("currencyCode"), _singleStringArray("uint16"));

        (string[] memory retNames, string[] memory retTypes) = utilities.getSchema(1000005);
        assertEq(retNames[0], "currencyCode");
        assertEq(retTypes[0], "uint16");
    }

    function test_addQualificationURL() public {
        _addDefaultTopic(1000006, "Qualification URL", _singleStringArray("urls"), _singleStringArray("string[]"));

        (string[] memory retNames, string[] memory retTypes) = utilities.getSchema(1000006);
        assertEq(retNames[0], "urls");
        assertEq(retTypes[0], "string[]");
    }

    function test_addERC3643Certificate() public {
        _addDefaultTopic(1000007, "ERC3643 Certificate", _singleStringArray("issuer"), _singleStringArray("address"));

        (string[] memory retNames, string[] memory retTypes) = utilities.getSchema(1000007);
        assertEq(retNames[0], "issuer");
        assertEq(retTypes[0], "address");
    }

    // =========================================================================
    //  Validation and permissioning
    // =========================================================================

    function test_revertMismatchedNameTypes() public {
        string[] memory names = _singleStringArray("field1");
        string[] memory types = new string[](2);
        types[0] = "uint256";
        types[1] = "uint8";

        vm.prank(admin);
        vm.expectRevert(bytes("Field name/type count mismatch"));
        utilities.addTopic(1234, "BrokenTopic", _encodeNames(names), _encodeTypes(types));
    }

    function test_revertNonTopicManagerCannotAdd() public {
        vm.prank(user);
        vm.expectRevert();
        utilities.addTopic(
            1000002, "LEI", _encodeNames(_singleStringArray("lei")), _encodeTypes(_singleStringArray("string"))
        );
    }

    // =========================================================================
    //  addTopic - additional validation
    // =========================================================================

    function test_addTopic_revertEmptyName() public {
        vm.prank(admin);
        vm.expectRevert(bytes("Empty topic name"));
        utilities.addTopic(
            1001, "", _encodeNames(_singleStringArray("field1")), _encodeTypes(_singleStringArray("string"))
        );
    }

    function test_addTopic_revertAlreadyExists() public {
        _addDefaultTopic(1001, "Test", _singleStringArray("field1"), _singleStringArray("string"));

        vm.prank(admin);
        vm.expectRevert(bytes("Topic already exists"));
        utilities.addTopic(
            1001, "Test", _encodeNames(_singleStringArray("field1")), _encodeTypes(_singleStringArray("string"))
        );
    }

    function test_addTopic_revertEmptyFieldNamesArrayMismatch() public {
        string[] memory names = new string[](0);
        string[] memory types = _singleStringArray("string");

        vm.prank(admin);
        vm.expectRevert(bytes("Field name/type count mismatch"));
        utilities.addTopic(1001, "Test", _encodeNames(names), _encodeTypes(types));
    }

    function test_addTopic_revertEmptyFieldName() public {
        vm.prank(admin);
        vm.expectRevert(bytes("Empty field name"));
        utilities.addTopic(
            1001, "Test", _encodeNames(_singleStringArray("")), _encodeTypes(_singleStringArray("string"))
        );
    }

    function test_addTopic_revertEmptyFieldType() public {
        vm.prank(admin);
        vm.expectRevert(bytes("Empty field type"));
        utilities.addTopic(
            1001, "Test", _encodeNames(_singleStringArray("field1")), _encodeTypes(_singleStringArray(""))
        );
    }

    function test_addTopic_emptyArraysBothSides() public {
        string[] memory names = new string[](0);
        string[] memory types = new string[](0);

        bytes memory encodedNames = _encodeNames(names);
        bytes memory encodedTypes = _encodeTypes(types);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true, address(utilities));
        emit IIdentityUtilities.TopicAdded(1001, "Empty Arrays Topic", encodedNames, encodedTypes);
        utilities.addTopic(1001, "Empty Arrays Topic", encodedNames, encodedTypes);

        IIdentityUtilities.TopicInfo memory topic = utilities.getTopic(1001);
        assertEq(topic.name, "Empty Arrays Topic");
        assertEq(topic.encodedFieldNames, encodedNames);
        assertEq(topic.encodedFieldTypes, encodedTypes);
    }

    function test_addTopic_complexFieldTypes() public {
        string[] memory names = new string[](5);
        names[0] = "address";
        names[1] = "uint256";
        names[2] = "bool";
        names[3] = "string";
        names[4] = "bytes";
        string[] memory types = new string[](5);
        types[0] = "address";
        types[1] = "uint256";
        types[2] = "bool";
        types[3] = "string";
        types[4] = "bytes";

        bytes memory encodedNames = _encodeNames(names);
        bytes memory encodedTypes = _encodeTypes(types);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true, address(utilities));
        emit IIdentityUtilities.TopicAdded(1001, "Complex Topic", encodedNames, encodedTypes);
        utilities.addTopic(1001, "Complex Topic", encodedNames, encodedTypes);

        IIdentityUtilities.TopicInfo memory topic = utilities.getTopic(1001);
        assertEq(topic.name, "Complex Topic");
        assertEq(topic.encodedFieldNames, encodedNames);
        assertEq(topic.encodedFieldTypes, encodedTypes);
    }

    // =========================================================================
    //  updateTopic
    // =========================================================================

    function test_updateTopic_success() public {
        _addDefaultTopic(1001, "Initial", _singleStringArray("field1"), _singleStringArray("string"));

        string[] memory newNames = new string[](2);
        newNames[0] = "field1";
        newNames[1] = "field2";
        string[] memory newTypes = new string[](2);
        newTypes[0] = "string";
        newTypes[1] = "uint256";

        bytes memory encodedNames = _encodeNames(newNames);
        bytes memory encodedTypes = _encodeTypes(newTypes);

        vm.prank(admin);
        vm.expectEmit(true, true, true, true, address(utilities));
        emit IIdentityUtilities.TopicUpdated(1001, "Updated", encodedNames, encodedTypes);
        utilities.updateTopic(1001, "Updated", encodedNames, encodedTypes);

        IIdentityUtilities.TopicInfo memory topic = utilities.getTopic(1001);
        assertEq(topic.name, "Updated");
        assertEq(topic.encodedFieldNames, encodedNames);
        assertEq(topic.encodedFieldTypes, encodedTypes);
    }

    function test_updateTopic_revertNonExistent() public {
        vm.prank(admin);
        vm.expectRevert(bytes("Topic does not exist"));
        utilities.updateTopic(
            9999, "Updated", _encodeNames(_singleStringArray("field1")), _encodeTypes(_singleStringArray("string"))
        );
    }

    function test_updateTopic_revertEmptyName() public {
        _addDefaultTopic(1001, "Initial", _singleStringArray("field1"), _singleStringArray("string"));

        vm.prank(admin);
        vm.expectRevert(bytes("Empty topic name"));
        utilities.updateTopic(
            1001, "", _encodeNames(_singleStringArray("field1")), _encodeTypes(_singleStringArray("string"))
        );
    }

    function test_updateTopic_revertMismatch() public {
        _addDefaultTopic(1001, "Initial", _singleStringArray("field1"), _singleStringArray("string"));

        string[] memory names = _singleStringArray("field1");
        string[] memory types = new string[](2);
        types[0] = "string";
        types[1] = "uint256";

        vm.prank(admin);
        vm.expectRevert(bytes("Field name/type count mismatch"));
        utilities.updateTopic(1001, "Updated", _encodeNames(names), _encodeTypes(types));
    }

    function test_updateTopic_revertEmptyFieldName() public {
        _addDefaultTopic(1001, "Initial", _singleStringArray("field1"), _singleStringArray("string"));

        vm.prank(admin);
        vm.expectRevert(bytes("Empty field name"));
        utilities.updateTopic(
            1001, "Updated", _encodeNames(_singleStringArray("")), _encodeTypes(_singleStringArray("string"))
        );
    }

    function test_updateTopic_revertEmptyFieldType() public {
        _addDefaultTopic(1001, "Initial", _singleStringArray("field1"), _singleStringArray("string"));

        vm.prank(admin);
        vm.expectRevert(bytes("Empty field type"));
        utilities.updateTopic(
            1001, "Updated", _encodeNames(_singleStringArray("field1")), _encodeTypes(_singleStringArray(""))
        );
    }

    function test_updateTopic_revertNonManager() public {
        _addDefaultTopic(1001, "Initial", _singleStringArray("field1"), _singleStringArray("string"));

        vm.prank(user);
        vm.expectRevert();
        utilities.updateTopic(
            1001, "Updated", _encodeNames(_singleStringArray("field1")), _encodeTypes(_singleStringArray("string"))
        );
    }

    // =========================================================================
    //  removeTopic
    // =========================================================================

    function test_removeTopic_success() public {
        _addDefaultTopic(1001, "Test", _singleStringArray("field1"), _singleStringArray("string"));

        vm.prank(admin);
        vm.expectEmit(true, true, true, true, address(utilities));
        emit IIdentityUtilities.TopicRemoved(1001);
        utilities.removeTopic(1001);

        IIdentityUtilities.TopicInfo memory topic = utilities.getTopic(1001);
        assertEq(topic.name, "");
        assertEq(topic.encodedFieldNames, bytes(""));
        assertEq(topic.encodedFieldTypes, bytes(""));
    }

    function test_removeTopic_revertNonExistent() public {
        vm.prank(admin);
        vm.expectRevert(bytes("Topic does not exist"));
        utilities.removeTopic(9999);
    }

    function test_removeTopic_revertNonManager() public {
        _addDefaultTopic(1001, "Test", _singleStringArray("field1"), _singleStringArray("string"));

        vm.prank(user);
        vm.expectRevert();
        utilities.removeTopic(1001);
    }

    function test_removeTopic_thenReadd() public {
        bytes memory encodedNames = _encodeNames(_singleStringArray("field1"));
        bytes memory encodedTypes = _encodeTypes(_singleStringArray("string"));

        vm.startPrank(admin);
        utilities.addTopic(1001, "Test", encodedNames, encodedTypes);
        utilities.removeTopic(1001);

        vm.expectEmit(true, true, true, true, address(utilities));
        emit IIdentityUtilities.TopicAdded(1001, "Test", encodedNames, encodedTypes);
        utilities.addTopic(1001, "Test", encodedNames, encodedTypes);
        vm.stopPrank();

        IIdentityUtilities.TopicInfo memory topic = utilities.getTopic(1001);
        assertEq(topic.name, "Test");
        assertEq(topic.encodedFieldNames, encodedNames);
        assertEq(topic.encodedFieldTypes, encodedTypes);
    }

    // =========================================================================
    //  getTopic
    // =========================================================================

    function test_getTopic_nonExistent() public view {
        IIdentityUtilities.TopicInfo memory topic = utilities.getTopic(9999);
        assertEq(topic.name, "");
        assertEq(topic.encodedFieldNames, bytes(""));
        assertEq(topic.encodedFieldTypes, bytes(""));
    }

    function test_getTopic_existing() public {
        string[] memory names = new string[](3);
        names[0] = "field1";
        names[1] = "field2";
        names[2] = "field3";
        string[] memory types = new string[](3);
        types[0] = "string";
        types[1] = "uint256";
        types[2] = "bool";

        bytes memory encodedNames = _encodeNames(names);
        bytes memory encodedTypes = _encodeTypes(types);

        _addDefaultTopic(1001, "Test", names, types);

        IIdentityUtilities.TopicInfo memory topic = utilities.getTopic(1001);
        assertEq(topic.name, "Test");
        assertEq(topic.encodedFieldNames, encodedNames);
        assertEq(topic.encodedFieldTypes, encodedTypes);
    }

    function test_getTopic_afterUpdate() public {
        _addDefaultTopic(1001, "Initial", _singleStringArray("field1"), _singleStringArray("string"));

        string[] memory newNames = new string[](2);
        newNames[0] = "field1";
        newNames[1] = "field2";
        string[] memory newTypes = new string[](2);
        newTypes[0] = "string";
        newTypes[1] = "uint256";

        bytes memory newEncodedNames = _encodeNames(newNames);
        bytes memory newEncodedTypes = _encodeTypes(newTypes);

        vm.prank(admin);
        utilities.updateTopic(1001, "Updated", newEncodedNames, newEncodedTypes);

        IIdentityUtilities.TopicInfo memory topic = utilities.getTopic(1001);
        assertEq(topic.name, "Updated");
        assertEq(topic.encodedFieldNames, newEncodedNames);
        assertEq(topic.encodedFieldTypes, newEncodedTypes);
    }

    // =========================================================================
    //  getFieldNames
    // =========================================================================

    function test_getFieldNames_nonExistent() public view {
        string[] memory names = utilities.getFieldNames(9999);
        assertEq(names.length, 0);
    }

    function test_getFieldNames_existing() public {
        string[] memory names = new string[](3);
        names[0] = "field1";
        names[1] = "field2";
        names[2] = "field3";
        string[] memory types = new string[](3);
        types[0] = "string";
        types[1] = "uint256";
        types[2] = "bool";

        _addDefaultTopic(1001, "Test", names, types);

        string[] memory retNames = utilities.getFieldNames(1001);
        assertEq(retNames.length, 3);
        assertEq(retNames[0], "field1");
        assertEq(retNames[1], "field2");
        assertEq(retNames[2], "field3");
    }

    function test_getFieldNames_afterUpdate() public {
        _addDefaultTopic(1001, "Initial", _singleStringArray("field1"), _singleStringArray("string"));

        string[] memory newNames = new string[](2);
        newNames[0] = "newField1";
        newNames[1] = "newField2";
        string[] memory newTypes = new string[](2);
        newTypes[0] = "string";
        newTypes[1] = "uint256";

        vm.prank(admin);
        utilities.updateTopic(1001, "Updated", _encodeNames(newNames), _encodeTypes(newTypes));

        string[] memory retNames = utilities.getFieldNames(1001);
        assertEq(retNames.length, 2);
        assertEq(retNames[0], "newField1");
        assertEq(retNames[1], "newField2");
    }

    function test_getFieldNames_afterRemove() public {
        _addDefaultTopic(1001, "Test", _singleStringArray("field1"), _singleStringArray("string"));

        vm.prank(admin);
        utilities.removeTopic(1001);

        string[] memory retNames = utilities.getFieldNames(1001);
        assertEq(retNames.length, 0);
    }

    // =========================================================================
    //  getFieldTypes
    // =========================================================================

    function test_getFieldTypes_nonExistent() public view {
        string[] memory types = utilities.getFieldTypes(9999);
        assertEq(types.length, 0);
    }

    function test_getFieldTypes_existing() public {
        string[] memory names = new string[](3);
        names[0] = "field1";
        names[1] = "field2";
        names[2] = "field3";
        string[] memory types = new string[](3);
        types[0] = "string";
        types[1] = "uint256";
        types[2] = "bool";

        _addDefaultTopic(1001, "Test", names, types);

        string[] memory retTypes = utilities.getFieldTypes(1001);
        assertEq(retTypes.length, 3);
        assertEq(retTypes[0], "string");
        assertEq(retTypes[1], "uint256");
        assertEq(retTypes[2], "bool");
    }

    function test_getFieldTypes_afterUpdate() public {
        _addDefaultTopic(1001, "Initial", _singleStringArray("field1"), _singleStringArray("string"));

        string[] memory newNames = new string[](2);
        newNames[0] = "newField1";
        newNames[1] = "newField2";
        string[] memory newTypes = new string[](2);
        newTypes[0] = "string";
        newTypes[1] = "uint256";

        vm.prank(admin);
        utilities.updateTopic(1001, "Updated", _encodeNames(newNames), _encodeTypes(newTypes));

        string[] memory retTypes = utilities.getFieldTypes(1001);
        assertEq(retTypes.length, 2);
        assertEq(retTypes[0], "string");
        assertEq(retTypes[1], "uint256");
    }

    function test_getFieldTypes_afterRemove() public {
        _addDefaultTopic(1001, "Test", _singleStringArray("field1"), _singleStringArray("string"));

        vm.prank(admin);
        utilities.removeTopic(1001);

        string[] memory retTypes = utilities.getFieldTypes(1001);
        assertEq(retTypes.length, 0);
    }

    // =========================================================================
    //  getSchema
    // =========================================================================

    function test_getSchema_nonExistent() public view {
        (string[] memory names, string[] memory types) = utilities.getSchema(9999);
        assertEq(names.length, 0);
        assertEq(types.length, 0);
    }

    function test_getSchema_existing() public {
        string[] memory names = new string[](3);
        names[0] = "field1";
        names[1] = "field2";
        names[2] = "field3";
        string[] memory types = new string[](3);
        types[0] = "string";
        types[1] = "uint256";
        types[2] = "bool";

        _addDefaultTopic(1001, "Test", names, types);

        (string[] memory retNames, string[] memory retTypes) = utilities.getSchema(1001);
        assertEq(retNames.length, 3);
        assertEq(retTypes.length, 3);
        assertEq(retNames[0], "field1");
        assertEq(retNames[1], "field2");
        assertEq(retNames[2], "field3");
        assertEq(retTypes[0], "string");
        assertEq(retTypes[1], "uint256");
        assertEq(retTypes[2], "bool");
    }

    function test_getSchema_afterUpdate() public {
        _addDefaultTopic(1001, "Initial", _singleStringArray("field1"), _singleStringArray("string"));

        string[] memory newNames = new string[](2);
        newNames[0] = "newField1";
        newNames[1] = "newField2";
        string[] memory newTypes = new string[](2);
        newTypes[0] = "string";
        newTypes[1] = "uint256";

        vm.prank(admin);
        utilities.updateTopic(1001, "Updated", _encodeNames(newNames), _encodeTypes(newTypes));

        (string[] memory retNames, string[] memory retTypes) = utilities.getSchema(1001);
        assertEq(retNames.length, 2);
        assertEq(retTypes.length, 2);
        assertEq(retNames[0], "newField1");
        assertEq(retNames[1], "newField2");
        assertEq(retTypes[0], "string");
        assertEq(retTypes[1], "uint256");
    }

    function test_getSchema_afterRemove() public {
        _addDefaultTopic(1001, "Test", _singleStringArray("field1"), _singleStringArray("string"));

        vm.prank(admin);
        utilities.removeTopic(1001);

        (string[] memory retNames, string[] memory retTypes) = utilities.getSchema(1001);
        assertEq(retNames.length, 0);
        assertEq(retTypes.length, 0);
    }

    // =========================================================================
    //  getTopicInfos
    // =========================================================================

    function test_getTopicInfos_emptyInput() public view {
        uint256[] memory ids = new uint256[](0);
        IIdentityUtilities.TopicInfo[] memory result = utilities.getTopicInfos(ids);
        assertEq(result.length, 0);
    }

    function test_getTopicInfos_singleExisting() public {
        bytes memory encodedNames = _encodeNames(_singleStringArray("field1"));
        bytes memory encodedTypes = _encodeTypes(_singleStringArray("string"));

        _addDefaultTopic(1001, "Test", _singleStringArray("field1"), _singleStringArray("string"));

        uint256[] memory ids = new uint256[](1);
        ids[0] = 1001;
        IIdentityUtilities.TopicInfo[] memory result = utilities.getTopicInfos(ids);
        assertEq(result.length, 1);
        assertEq(result[0].name, "Test");
        assertEq(result[0].encodedFieldNames, encodedNames);
        assertEq(result[0].encodedFieldTypes, encodedTypes);
    }

    function test_getTopicInfos_multiple() public {
        vm.startPrank(admin);
        utilities.addTopic(10, "A", _encodeNames(_singleStringArray("f1")), _encodeTypes(_singleStringArray("string")));
        utilities.addTopic(20, "B", _encodeNames(_singleStringArray("f2")), _encodeTypes(_singleStringArray("uint256")));
        vm.stopPrank();

        uint256[] memory ids = new uint256[](2);
        ids[0] = 10;
        ids[1] = 20;
        IIdentityUtilities.TopicInfo[] memory result = utilities.getTopicInfos(ids);
        assertEq(result.length, 2);
        assertEq(result[0].name, "A");
        assertEq(result[1].name, "B");
        assertEq(result[0].encodedFieldNames, _encodeNames(_singleStringArray("f1")));
        assertEq(result[1].encodedFieldTypes, _encodeTypes(_singleStringArray("uint256")));
    }

    function test_getTopicInfos_multipleThreeTopics() public {
        vm.startPrank(admin);
        utilities.addTopic(
            1001, "Topic 1", _encodeNames(_singleStringArray("field1")), _encodeTypes(_singleStringArray("string"))
        );
        utilities.addTopic(
            1002, "Topic 2", _encodeNames(_singleStringArray("field2")), _encodeTypes(_singleStringArray("uint256"))
        );
        utilities.addTopic(
            1003, "Topic 3", _encodeNames(_singleStringArray("field3")), _encodeTypes(_singleStringArray("bool"))
        );
        vm.stopPrank();

        uint256[] memory ids = new uint256[](3);
        ids[0] = 1001;
        ids[1] = 1002;
        ids[2] = 1003;
        IIdentityUtilities.TopicInfo[] memory result = utilities.getTopicInfos(ids);
        assertEq(result.length, 3);
        assertEq(result[0].name, "Topic 1");
        assertEq(result[1].name, "Topic 2");
        assertEq(result[2].name, "Topic 3");
        assertEq(result[0].encodedFieldNames, _encodeNames(_singleStringArray("field1")));
        assertEq(result[1].encodedFieldTypes, _encodeTypes(_singleStringArray("uint256")));
        assertEq(result[2].encodedFieldTypes, _encodeTypes(_singleStringArray("bool")));
    }

    function test_getTopicInfos_nonExistent() public view {
        uint256[] memory ids = new uint256[](3);
        ids[0] = 9999;
        ids[1] = 8888;
        ids[2] = 7777;
        IIdentityUtilities.TopicInfo[] memory result = utilities.getTopicInfos(ids);
        assertEq(result.length, 3);
        assertEq(result[0].name, "");
        assertEq(result[1].name, "");
        assertEq(result[2].name, "");
        assertEq(result[0].encodedFieldNames, bytes(""));
        assertEq(result[1].encodedFieldNames, bytes(""));
        assertEq(result[2].encodedFieldNames, bytes(""));
    }

    function test_getTopicInfos_mixed() public {
        bytes memory encodedNames = _encodeNames(_singleStringArray("field1"));
        bytes memory encodedTypes = _encodeTypes(_singleStringArray("string"));

        _addDefaultTopic(1001, "Test", _singleStringArray("field1"), _singleStringArray("string"));

        uint256[] memory ids = new uint256[](2);
        ids[0] = 1001;
        ids[1] = 9999;
        IIdentityUtilities.TopicInfo[] memory result = utilities.getTopicInfos(ids);
        assertEq(result.length, 2);
        assertEq(result[0].name, "Test");
        assertEq(result[0].encodedFieldNames, encodedNames);
        assertEq(result[0].encodedFieldTypes, encodedTypes);
        assertEq(result[1].name, "");
        assertEq(result[1].encodedFieldNames, bytes(""));
        assertEq(result[1].encodedFieldTypes, bytes(""));
    }

    // =========================================================================
    //  Access control - full CRUD by admin
    // =========================================================================

    function test_accessControl_fullCRUD() public {
        bytes memory encodedNames = _encodeNames(_singleStringArray("field1"));
        bytes memory encodedTypes = _encodeTypes(_singleStringArray("string"));

        vm.startPrank(admin);

        // Add
        vm.expectEmit(true, true, true, true, address(utilities));
        emit IIdentityUtilities.TopicAdded(1001, "Test", encodedNames, encodedTypes);
        utilities.addTopic(1001, "Test", encodedNames, encodedTypes);

        // Update
        vm.expectEmit(true, true, true, true, address(utilities));
        emit IIdentityUtilities.TopicUpdated(1001, "Updated", encodedNames, encodedTypes);
        utilities.updateTopic(1001, "Updated", encodedNames, encodedTypes);

        // Remove
        vm.expectEmit(true, true, true, true, address(utilities));
        emit IIdentityUtilities.TopicRemoved(1001);
        utilities.removeTopic(1001);

        vm.stopPrank();

        IIdentityUtilities.TopicInfo memory topic = utilities.getTopic(1001);
        assertEq(topic.name, "");
    }

    // =========================================================================
    //  Edge cases and stress testing
    // =========================================================================

    function test_topicWithManyFields() public {
        string[] memory names = new string[](10);
        string[] memory types = new string[](10);
        for (uint256 i = 0; i < 10; i++) {
            names[i] = string(abi.encodePacked("field", vm.toString(i)));
            types[i] = i % 2 == 0 ? "string" : "uint256";
        }

        _addDefaultTopic(1001, "Large Topic", names, types);

        string[] memory retNames = utilities.getFieldNames(1001);
        string[] memory retTypes = utilities.getFieldTypes(1001);
        assertEq(retNames.length, 10);
        assertEq(retTypes.length, 10);
        assertEq(retNames[0], "field0");
        assertEq(retNames[9], "field9");
        assertEq(retTypes[0], "string");
        assertEq(retTypes[1], "uint256");
    }

    function test_topicWithLongNames() public {
        string memory longName = "this_is_a_very_long_field_name_that_might_be_used_in_real_world_scenarios";
        string memory longType = "this_is_a_very_long_field_type_that_might_be_used_in_real_world_scenarios";

        _addDefaultTopic(1001, "Long Names Topic", _singleStringArray(longName), _singleStringArray(longType));

        string[] memory retNames = utilities.getFieldNames(1001);
        string[] memory retTypes = utilities.getFieldTypes(1001);
        assertEq(retNames[0], longName);
        assertEq(retTypes[0], longType);
    }

    function test_rapidAddUpdateRemove() public {
        bytes memory encodedNames = _encodeNames(_singleStringArray("field1"));
        bytes memory encodedTypes = _encodeTypes(_singleStringArray("string"));

        vm.startPrank(admin);
        utilities.addTopic(1001, "Test", encodedNames, encodedTypes);
        utilities.updateTopic(1001, "Updated", encodedNames, encodedTypes);
        utilities.removeTopic(1001);
        vm.stopPrank();

        IIdentityUtilities.TopicInfo memory topic = utilities.getTopic(1001);
        assertEq(topic.name, "");
        assertEq(topic.encodedFieldNames, bytes(""));
        assertEq(topic.encodedFieldTypes, bytes(""));
    }

    function test_multipleTopicsSameFieldNamesDifferentTypes() public {
        vm.startPrank(admin);
        utilities.addTopic(
            1001, "Topic 1", _encodeNames(_singleStringArray("field1")), _encodeTypes(_singleStringArray("string"))
        );
        utilities.addTopic(
            1002, "Topic 2", _encodeNames(_singleStringArray("field1")), _encodeTypes(_singleStringArray("uint256"))
        );
        utilities.addTopic(
            1003, "Topic 3", _encodeNames(_singleStringArray("field1")), _encodeTypes(_singleStringArray("bool"))
        );
        vm.stopPrank();

        string[] memory types1 = utilities.getFieldTypes(1001);
        string[] memory types2 = utilities.getFieldTypes(1002);
        string[] memory types3 = utilities.getFieldTypes(1003);
        assertEq(types1[0], "string");
        assertEq(types2[0], "uint256");
        assertEq(types3[0], "bool");

        string[] memory names1 = utilities.getFieldNames(1001);
        string[] memory names2 = utilities.getFieldNames(1002);
        string[] memory names3 = utilities.getFieldNames(1003);
        assertEq(names1[0], "field1");
        assertEq(names2[0], "field1");
        assertEq(names3[0], "field1");
    }

    // =========================================================================
    //  getClaimsWithTopicInfo
    // =========================================================================

    function test_getClaimsWithTopicInfo() public {
        // Add topics
        vm.startPrank(admin);
        utilities.addTopic(
            1001, "KYC", _encodeNames(_singleStringArray("status")), _encodeTypes(_singleStringArray("string"))
        );
        utilities.addTopic(
            1002, "AML", _encodeNames(_singleStringArray("level")), _encodeTypes(_singleStringArray("uint8"))
        );
        vm.stopPrank();

        // Deploy ClaimIssuer and Identity
        (address claimIssuerOwner, uint256 claimIssuerOwnerPk) = makeAddrAndKey("ciOwner");
        address identityOwner = makeAddr("idOwner");
        (address claimSigner,) = makeAddrAndKey("claimSigner");

        ClaimIssuer ci = ClaimIssuerHelper.deployWithProxy(claimIssuerOwner);
        Identity identity = IdentityHelper.deployIdentityWithProxy(identityOwner);

        // Add CLAIM_SIGNER key to claim issuer for the claimIssuerOwner
        vm.prank(claimIssuerOwner);
        ci.addKey(ClaimSignerHelper.addressToKey(claimIssuerOwner), KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA);

        // Add CLAIM_SIGNER key to identity for claimSigner
        vm.prank(identityOwner);
        identity.addKey(ClaimSignerHelper.addressToKey(claimSigner), KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA);

        // Build claims
        bytes memory claimData1 = abi.encode("verified");
        bytes memory claimData2 = abi.encode(uint8(2));

        bytes memory sig1 = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(identity), 1001, claimData1);
        bytes memory sig2 = ClaimSignerHelper.signClaim(claimIssuerOwnerPk, address(identity), 1002, claimData2);

        // Add claims to identity via claimSigner (has CLAIM_SIGNER key)
        vm.startPrank(claimSigner);
        identity.addClaim(1001, 1, address(ci), sig1, claimData1, "https://example.com/kyc");
        identity.addClaim(1002, 1, address(ci), sig2, claimData2, "https://example.com/aml");
        vm.stopPrank();

        // Query
        uint256[] memory topicIds = new uint256[](2);
        topicIds[0] = 1001;
        topicIds[1] = 1002;
        IIdentityUtilities.ClaimInfo[] memory result = utilities.getClaimsWithTopicInfo(address(identity), topicIds);

        assertEq(result.length, 2);

        // Verify KYC claim
        assertEq(result[0].scheme, 1);
        assertEq(result[0].issuer, address(ci));
        assertTrue(result[0].isValid);
        assertEq(result[0].data, claimData1);
        assertEq(result[0].uri, "https://example.com/kyc");
        assertEq(result[0].topic.name, "KYC");
        assertEq(result[0].topic.encodedFieldNames, _encodeNames(_singleStringArray("status")));
        assertEq(result[0].topic.encodedFieldTypes, _encodeTypes(_singleStringArray("string")));

        // Verify AML claim
        assertEq(result[1].scheme, 1);
        assertEq(result[1].issuer, address(ci));
        assertTrue(result[1].isValid);
        assertEq(result[1].data, claimData2);
        assertEq(result[1].uri, "https://example.com/aml");
        assertEq(result[1].topic.name, "AML");
        assertEq(result[1].topic.encodedFieldNames, _encodeNames(_singleStringArray("level")));
        assertEq(result[1].topic.encodedFieldTypes, _encodeTypes(_singleStringArray("uint8")));

        // Decode and verify claim data
        string memory decodedKyc = abi.decode(result[0].data, (string));
        assertEq(decodedKyc, "verified");
        uint8 decodedAml = abi.decode(result[1].data, (uint8));
        assertEq(decodedAml, 2);
    }

    function test_getClaimsWithTopicInfo_selfAttestedClaim() public {
        // Add topic
        _addDefaultTopic(3004, "Test Topic", _singleStringArray("name"), _singleStringArray("string"));

        // Deploy Identity
        Identity identity = IdentityHelper.deployIdentityWithProxy(admin);

        // Add CLAIM_SIGNER key for admin on the identity
        vm.prank(admin);
        identity.addKey(ClaimSignerHelper.addressToKey(admin), KeyPurposes.CLAIM_SIGNER, KeyTypes.ECDSA);

        // Sign claim properly for self-attested claim
        bytes memory claimData = hex"";
        bytes memory signature = ClaimSignerHelper.signClaim(adminPk, address(identity), 3004, claimData);

        // Add a self-attested claim with valid signature
        vm.prank(admin);
        identity.addClaim(3004, 1, address(identity), signature, claimData, "https://example.com/claim");

        // Query
        uint256[] memory topicIds = new uint256[](1);
        topicIds[0] = 3004;
        IIdentityUtilities.ClaimInfo[] memory result = utilities.getClaimsWithTopicInfo(address(identity), topicIds);

        assertGt(result.length, 0);
        assertEq(result[0].issuer, address(identity));
    }

    // =========================================================================
    //  TestIdentityUtilities - _isClaimValid coverage
    // =========================================================================

    function test_isClaimValid_zeroAddressIssuer() public {
        TestIdentityUtilities testUtil = new TestIdentityUtilities();
        Identity identity = IdentityHelper.deployIdentityWithProxy(admin);

        bool result = testUtil.checkIsClaimValid(address(identity), 3007, address(0), hex"", hex"");
        assertFalse(result);
    }

    function test_isClaimValid_invalidContractIssuer() public {
        TestIdentityUtilities testUtil = new TestIdentityUtilities();
        Identity identity = IdentityHelper.deployIdentityWithProxy(admin);

        // Deploy a contract that does not implement isClaimValid (catches and returns false)
        TestContract invalidContract = new TestContract();

        bool result = testUtil.checkIsClaimValid(address(identity), 3008, address(invalidContract), hex"", hex"");
        assertFalse(result);
    }

    // =========================================================================
    //  UUPS upgrade
    // =========================================================================

    function test_upgrade_revertNonAdmin() public {
        address nonAdmin = makeAddr("nonAdmin");
        IdentityUtilities newImpl = new IdentityUtilities();

        vm.prank(nonAdmin);
        vm.expectRevert();
        utilities.upgradeToAndCall(address(newImpl), bytes(""));
    }

    function test_upgrade_successAsAdmin() public {
        IdentityUtilities newImpl = new IdentityUtilities();

        vm.prank(admin);
        utilities.upgradeToAndCall(address(newImpl), bytes(""));
    }

    // =========================================================================
    //  ERC1967 proxy deployment variant
    // =========================================================================

    function test_upgrade_viaERC1967Proxy_revertNonAdmin() public {
        address deployer = makeAddr("erc1967deployer");
        address nonAdmin = makeAddr("erc1967nonAdmin");

        IdentityUtilities impl = new IdentityUtilities();
        ERC1967Proxy proxy = new ERC1967Proxy(address(impl), abi.encodeCall(IdentityUtilities.initialize, (deployer)));
        IdentityUtilities proxyUtil = IdentityUtilities(address(proxy));

        IdentityUtilities newImpl = new IdentityUtilities();

        vm.prank(nonAdmin);
        vm.expectRevert();
        proxyUtil.upgradeToAndCall(address(newImpl), bytes(""));
    }

}
