/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../common";
import type {
  Migrations,
  MigrationsInterface,
} from "../../contracts/Migrations";

const _abi = [
  {
    inputs: [],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    inputs: [],
    name: "lastCompletedMigration",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "completed",
        type: "uint256",
      },
    ],
    name: "setCompleted",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newAddress",
        type: "address",
      },
    ],
    name: "upgrade",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

const _bytecode =
  "0x608060405234801561001057600080fd5b5061002b67af8eeeb3d929e30860c01b61008a60201b60201c565b610045675678b805fbd3258a60c01b61008a60201b60201c565b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555061008d565b50565b6105458061009c6000396000f3fe608060405234801561001057600080fd5b506004361061004c5760003560e01c80630900f010146100515780638da5cb5b1461006d578063fbdbad3c1461008b578063fdacd576146100a9575b600080fd5b61006b6004803603810190610066919061042b565b6100c5565b005b610075610284565b6040516100829190610467565b60405180910390f35b6100936102a8565b6040516100a0919061049b565b60405180910390f35b6100c360048036038101906100be91906104e2565b6102ae565b005b6100d967dbd6b9a435b1dc8f60c01b6103c5565b6100ed676c182490d01e59d360c01b6103c5565b61010167a0c1c5936ef55b6f60c01b6103c5565b61011567127e38246dce84f460c01b6103c5565b60008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff160361026c5761017c67ee800bfda844fe5e60c01b6103c5565b61019067f3cf14de33c276e460c01b6103c5565b6101a4679584692462fa32fe60c01b6103c5565b6101b867ce55c83b264fc22860c01b6103c5565b6101cc67adce67feaa8e275960c01b6103c5565b60008190506101e567145e417eed9ecf3760c01b6103c5565b6101f9673c632c8c20fc40ac60c01b6103c5565b8073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff1660e01b8152600401610234919061049b565b600060405180830381600087803b15801561024e57600080fd5b505af1158015610262573d6000803e3d6000fd5b5050505050610281565b610280679d724c9099e1197560c01b6103c5565b5b50565b60008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b60015481565b6102c267e2c4c0d2c0d0cb5460c01b6103c5565b6102d6676c182490d01e59d360c01b6103c5565b6102ea67a0c1c5936ef55b6f60c01b6103c5565b6102fe67127e38246dce84f460c01b6103c5565b60008054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff16036103ad5761036567ee800bfda844fe5e60c01b6103c5565b610379674fc5373ba0bfc32660c01b6103c5565b61038d672fa043c70ffd660760c01b6103c5565b6103a167185093bad62d7d9160c01b6103c5565b806001819055506103c2565b6103c1679d724c9099e1197560c01b6103c5565b5b50565b50565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006103f8826103cd565b9050919050565b610408816103ed565b811461041357600080fd5b50565b600081359050610425816103ff565b92915050565b600060208284031215610441576104406103c8565b5b600061044f84828501610416565b91505092915050565b610461816103ed565b82525050565b600060208201905061047c6000830184610458565b92915050565b6000819050919050565b61049581610482565b82525050565b60006020820190506104b0600083018461048c565b92915050565b6104bf81610482565b81146104ca57600080fd5b50565b6000813590506104dc816104b6565b92915050565b6000602082840312156104f8576104f76103c8565b5b6000610506848285016104cd565b9150509291505056fea2646970667358221220b870b6fa26b4b38629b135a48a10ad9247d6d30d4fbb1ae8f8d8116b4db118d264736f6c63430008110033";

type MigrationsConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: MigrationsConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class Migrations__factory extends ContractFactory {
  constructor(...args: MigrationsConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<Migrations> {
    return super.deploy(overrides || {}) as Promise<Migrations>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): Migrations {
    return super.attach(address) as Migrations;
  }
  override connect(signer: Signer): Migrations__factory {
    return super.connect(signer) as Migrations__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): MigrationsInterface {
    return new utils.Interface(_abi) as MigrationsInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): Migrations {
    return new Contract(address, _abi, signerOrProvider) as Migrations;
  }
}
