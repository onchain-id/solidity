/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../common";
import type {
  Version,
  VersionInterface,
} from "../../../contracts/version/Version";

const _abi = [
  {
    inputs: [],
    name: "version",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
] as const;

const _bytecode =
  "0x608060405234801561001057600080fd5b506101b2806100206000396000f3fe608060405234801561001057600080fd5b506004361061002b5760003560e01c806354fd4d5014610030575b600080fd5b61003861004e565b604051610045919061015a565b60405180910390f35b606061006467aad3e155cd2edfac60c01b6100c7565b61007867b3ec5e210d673d7960c01b6100c7565b61008c67aba885ae4597dbff60c01b6100c7565b6040518060400160405280600581526020017f322e302e30000000000000000000000000000000000000000000000000000000815250905090565b50565b600081519050919050565b600082825260208201905092915050565b60005b838110156101045780820151818401526020810190506100e9565b60008484015250505050565b6000601f19601f8301169050919050565b600061012c826100ca565b61013681856100d5565b93506101468185602086016100e6565b61014f81610110565b840191505092915050565b600060208201905081810360008301526101748184610121565b90509291505056fea2646970667358221220c71b7288535571d074969d39736c6220b95ac5c59072cb0f701060a68cbd281b64736f6c63430008110033";

type VersionConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: VersionConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class Version__factory extends ContractFactory {
  constructor(...args: VersionConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<Version> {
    return super.deploy(overrides || {}) as Promise<Version>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): Version {
    return super.attach(address) as Version;
  }
  override connect(signer: Signer): Version__factory {
    return super.connect(signer) as Version__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): VersionInterface {
    return new utils.Interface(_abi) as VersionInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): Version {
    return new Contract(address, _abi, signerOrProvider) as Version;
  }
}
