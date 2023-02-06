/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../../common";
import type {
  ImplementationAuthority,
  ImplementationAuthorityInterface,
} from "../../../contracts/proxy/ImplementationAuthority";

const _abi = [
  {
    inputs: [
      {
        internalType: "address",
        name: "implementation",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "newAddress",
        type: "address",
      },
    ],
    name: "UpdatedImplementation",
    type: "event",
  },
  {
    inputs: [],
    name: "getImplementation",
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
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_newImplementation",
        type: "address",
      },
    ],
    name: "updateImplementation",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
] as const;

const _bytecode =
  "0x608060405234801561001057600080fd5b5060405161091338038061091383398181016040528101906100329190610266565b61004e61004361013460201b60201c565b61013c60201b60201c565b61006867d07d18a37f4bca7b60c01b61020060201b60201c565b61008267b57162fcfa193e1e60c01b61020060201b60201c565b80600160006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506100dd6799fbaea3bf8e616860c01b61020060201b60201c565b6100f767160f38b86317382e60c01b61020060201b60201c565b7f87c4e67a766ffddda27f441d63853a36ae64fbb07775a7c59d395e064b204eeb8160405161012691906102a2565b60405180910390a1506102bd565b600033905090565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff169050816000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055508173ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff167f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e060405160405180910390a35050565b50565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b600061023382610208565b9050919050565b61024381610228565b811461024e57600080fd5b50565b6000815190506102608161023a565b92915050565b60006020828403121561027c5761027b610203565b5b600061028a84828501610251565b91505092915050565b61029c81610228565b82525050565b60006020820190506102b76000830184610293565b92915050565b610647806102cc6000396000f3fe608060405234801561001057600080fd5b50600436106100575760003560e01c8063025b22bc1461005c578063715018a6146100785780638da5cb5b14610082578063aaf10f42146100a0578063f2fde38b146100be575b600080fd5b610076600480360381019061007191906104ab565b6100da565b005b6100806101d5565b005b61008a6101e9565b60405161009791906104e7565b60405180910390f35b6100a8610212565b6040516100b591906104e7565b60405180910390f35b6100d860048036038101906100d391906104ab565b610278565b005b6100ee67fe96974b337e3db560c01b6102fb565b6100f66102fe565b61010a670e2b82cfa004d8f260c01b6102fb565b61011e679b141fc444e17eaa60c01b6102fb565b61013267bb5eb673fd71b6ae60c01b6102fb565b80600160006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550610187674b68502b4910936660c01b6102fb565b61019b67512791b493e7d9ec60c01b6102fb565b7f87c4e67a766ffddda27f441d63853a36ae64fbb07775a7c59d395e064b204eeb816040516101ca91906104e7565b60405180910390a150565b6101dd6102fe565b6101e7600061037c565b565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff16905090565b600061022867fccb5cdcbd9d70d060c01b6102fb565b61023c67f2f401c89e576ab260c01b6102fb565b610250670b65ec15ba2bcc9660c01b6102fb565b600160009054906101000a900473ffffffffffffffffffffffffffffffffffffffff16905090565b6102806102fe565b600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16036102ef576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004016102e690610585565b60405180910390fd5b6102f88161037c565b50565b50565b610306610440565b73ffffffffffffffffffffffffffffffffffffffff166103246101e9565b73ffffffffffffffffffffffffffffffffffffffff161461037a576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401610371906105f1565b60405180910390fd5b565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff169050816000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055508173ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff167f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e060405160405180910390a35050565b600033905090565b600080fd5b600073ffffffffffffffffffffffffffffffffffffffff82169050919050565b60006104788261044d565b9050919050565b6104888161046d565b811461049357600080fd5b50565b6000813590506104a58161047f565b92915050565b6000602082840312156104c1576104c0610448565b5b60006104cf84828501610496565b91505092915050565b6104e18161046d565b82525050565b60006020820190506104fc60008301846104d8565b92915050565b600082825260208201905092915050565b7f4f776e61626c653a206e6577206f776e657220697320746865207a65726f206160008201527f6464726573730000000000000000000000000000000000000000000000000000602082015250565b600061056f602683610502565b915061057a82610513565b604082019050919050565b6000602082019050818103600083015261059e81610562565b9050919050565b7f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e6572600082015250565b60006105db602083610502565b91506105e6826105a5565b602082019050919050565b6000602082019050818103600083015261060a816105ce565b905091905056fea2646970667358221220a46f31d001bc631d72fad06754014314931f46ead3088be9562349b586ed3f9a64736f6c63430008110033";

type ImplementationAuthorityConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: ImplementationAuthorityConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class ImplementationAuthority__factory extends ContractFactory {
  constructor(...args: ImplementationAuthorityConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    implementation: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ImplementationAuthority> {
    return super.deploy(
      implementation,
      overrides || {}
    ) as Promise<ImplementationAuthority>;
  }
  override getDeployTransaction(
    implementation: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(implementation, overrides || {});
  }
  override attach(address: string): ImplementationAuthority {
    return super.attach(address) as ImplementationAuthority;
  }
  override connect(signer: Signer): ImplementationAuthority__factory {
    return super.connect(signer) as ImplementationAuthority__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): ImplementationAuthorityInterface {
    return new utils.Interface(_abi) as ImplementationAuthorityInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): ImplementationAuthority {
    return new Contract(
      address,
      _abi,
      signerOrProvider
    ) as ImplementationAuthority;
  }
}
