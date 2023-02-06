/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PopulatedTransaction,
  Signer,
  utils,
} from "ethers";
import type {
  FunctionFragment,
  Result,
  EventFragment,
} from "@ethersproject/abi";
import type { Listener, Provider } from "@ethersproject/providers";
import type {
  TypedEventFilter,
  TypedEvent,
  TypedListener,
  OnEvent,
  PromiseOrValue,
} from "../../common";

export interface IIdFactoryInterface extends utils.Interface {
  functions: {
    "addTokenFactory(address)": FunctionFragment;
    "createIdentity(address,string)": FunctionFragment;
    "createTokenIdentity(address,address,string)": FunctionFragment;
    "getIdentity(address)": FunctionFragment;
    "getWallets(address)": FunctionFragment;
    "isSaltTaken(string)": FunctionFragment;
    "isTokenFactory(address)": FunctionFragment;
    "linkWallet(address)": FunctionFragment;
    "removeTokenFactory(address)": FunctionFragment;
    "unlinkWallet(address)": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "addTokenFactory"
      | "createIdentity"
      | "createTokenIdentity"
      | "getIdentity"
      | "getWallets"
      | "isSaltTaken"
      | "isTokenFactory"
      | "linkWallet"
      | "removeTokenFactory"
      | "unlinkWallet"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "addTokenFactory",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "createIdentity",
    values: [PromiseOrValue<string>, PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "createTokenIdentity",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<string>,
      PromiseOrValue<string>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "getIdentity",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "getWallets",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "isSaltTaken",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "isTokenFactory",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "linkWallet",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "removeTokenFactory",
    values: [PromiseOrValue<string>]
  ): string;
  encodeFunctionData(
    functionFragment: "unlinkWallet",
    values: [PromiseOrValue<string>]
  ): string;

  decodeFunctionResult(
    functionFragment: "addTokenFactory",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "createIdentity",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "createTokenIdentity",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getIdentity",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "getWallets", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "isSaltTaken",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "isTokenFactory",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "linkWallet", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "removeTokenFactory",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "unlinkWallet",
    data: BytesLike
  ): Result;

  events: {
    "Deployed(address)": EventFragment;
    "TokenFactoryAdded(address)": EventFragment;
    "TokenFactoryRemoved(address)": EventFragment;
    "TokenLinked(address,address)": EventFragment;
    "WalletLinked(address,address)": EventFragment;
    "WalletUnlinked(address,address)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "Deployed"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "TokenFactoryAdded"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "TokenFactoryRemoved"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "TokenLinked"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "WalletLinked"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "WalletUnlinked"): EventFragment;
}

export interface DeployedEventObject {
  _addr: string;
}
export type DeployedEvent = TypedEvent<[string], DeployedEventObject>;

export type DeployedEventFilter = TypedEventFilter<DeployedEvent>;

export interface TokenFactoryAddedEventObject {
  factory: string;
}
export type TokenFactoryAddedEvent = TypedEvent<
  [string],
  TokenFactoryAddedEventObject
>;

export type TokenFactoryAddedEventFilter =
  TypedEventFilter<TokenFactoryAddedEvent>;

export interface TokenFactoryRemovedEventObject {
  factory: string;
}
export type TokenFactoryRemovedEvent = TypedEvent<
  [string],
  TokenFactoryRemovedEventObject
>;

export type TokenFactoryRemovedEventFilter =
  TypedEventFilter<TokenFactoryRemovedEvent>;

export interface TokenLinkedEventObject {
  token: string;
  identity: string;
}
export type TokenLinkedEvent = TypedEvent<
  [string, string],
  TokenLinkedEventObject
>;

export type TokenLinkedEventFilter = TypedEventFilter<TokenLinkedEvent>;

export interface WalletLinkedEventObject {
  wallet: string;
  identity: string;
}
export type WalletLinkedEvent = TypedEvent<
  [string, string],
  WalletLinkedEventObject
>;

export type WalletLinkedEventFilter = TypedEventFilter<WalletLinkedEvent>;

export interface WalletUnlinkedEventObject {
  wallet: string;
  identity: string;
}
export type WalletUnlinkedEvent = TypedEvent<
  [string, string],
  WalletUnlinkedEventObject
>;

export type WalletUnlinkedEventFilter = TypedEventFilter<WalletUnlinkedEvent>;

export interface IIdFactory extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IIdFactoryInterface;

  queryFilter<TEvent extends TypedEvent>(
    event: TypedEventFilter<TEvent>,
    fromBlockOrBlockhash?: string | number | undefined,
    toBlock?: string | number | undefined
  ): Promise<Array<TEvent>>;

  listeners<TEvent extends TypedEvent>(
    eventFilter?: TypedEventFilter<TEvent>
  ): Array<TypedListener<TEvent>>;
  listeners(eventName?: string): Array<Listener>;
  removeAllListeners<TEvent extends TypedEvent>(
    eventFilter: TypedEventFilter<TEvent>
  ): this;
  removeAllListeners(eventName?: string): this;
  off: OnEvent<this>;
  on: OnEvent<this>;
  once: OnEvent<this>;
  removeListener: OnEvent<this>;

  functions: {
    addTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    createIdentity(
      _wallet: PromiseOrValue<string>,
      _salt: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    createTokenIdentity(
      _token: PromiseOrValue<string>,
      _owner: PromiseOrValue<string>,
      _salt: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    getIdentity(
      _wallet: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[string]>;

    getWallets(
      _identity: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[string[]]>;

    isSaltTaken(
      _salt: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[boolean]>;

    isTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<[boolean]>;

    linkWallet(
      _newWallet: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    removeTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    unlinkWallet(
      _oldWallet: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;
  };

  addTokenFactory(
    _factory: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  createIdentity(
    _wallet: PromiseOrValue<string>,
    _salt: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  createTokenIdentity(
    _token: PromiseOrValue<string>,
    _owner: PromiseOrValue<string>,
    _salt: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  getIdentity(
    _wallet: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<string>;

  getWallets(
    _identity: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<string[]>;

  isSaltTaken(
    _salt: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<boolean>;

  isTokenFactory(
    _factory: PromiseOrValue<string>,
    overrides?: CallOverrides
  ): Promise<boolean>;

  linkWallet(
    _newWallet: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  removeTokenFactory(
    _factory: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  unlinkWallet(
    _oldWallet: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  callStatic: {
    addTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;

    createIdentity(
      _wallet: PromiseOrValue<string>,
      _salt: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<string>;

    createTokenIdentity(
      _token: PromiseOrValue<string>,
      _owner: PromiseOrValue<string>,
      _salt: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<string>;

    getIdentity(
      _wallet: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<string>;

    getWallets(
      _identity: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<string[]>;

    isSaltTaken(
      _salt: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<boolean>;

    isTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<boolean>;

    linkWallet(
      _newWallet: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;

    removeTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;

    unlinkWallet(
      _oldWallet: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<void>;
  };

  filters: {
    "Deployed(address)"(
      _addr?: PromiseOrValue<string> | null
    ): DeployedEventFilter;
    Deployed(_addr?: PromiseOrValue<string> | null): DeployedEventFilter;

    "TokenFactoryAdded(address)"(
      factory?: PromiseOrValue<string> | null
    ): TokenFactoryAddedEventFilter;
    TokenFactoryAdded(
      factory?: PromiseOrValue<string> | null
    ): TokenFactoryAddedEventFilter;

    "TokenFactoryRemoved(address)"(
      factory?: PromiseOrValue<string> | null
    ): TokenFactoryRemovedEventFilter;
    TokenFactoryRemoved(
      factory?: PromiseOrValue<string> | null
    ): TokenFactoryRemovedEventFilter;

    "TokenLinked(address,address)"(
      token?: PromiseOrValue<string> | null,
      identity?: PromiseOrValue<string> | null
    ): TokenLinkedEventFilter;
    TokenLinked(
      token?: PromiseOrValue<string> | null,
      identity?: PromiseOrValue<string> | null
    ): TokenLinkedEventFilter;

    "WalletLinked(address,address)"(
      wallet?: PromiseOrValue<string> | null,
      identity?: PromiseOrValue<string> | null
    ): WalletLinkedEventFilter;
    WalletLinked(
      wallet?: PromiseOrValue<string> | null,
      identity?: PromiseOrValue<string> | null
    ): WalletLinkedEventFilter;

    "WalletUnlinked(address,address)"(
      wallet?: PromiseOrValue<string> | null,
      identity?: PromiseOrValue<string> | null
    ): WalletUnlinkedEventFilter;
    WalletUnlinked(
      wallet?: PromiseOrValue<string> | null,
      identity?: PromiseOrValue<string> | null
    ): WalletUnlinkedEventFilter;
  };

  estimateGas: {
    addTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    createIdentity(
      _wallet: PromiseOrValue<string>,
      _salt: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    createTokenIdentity(
      _token: PromiseOrValue<string>,
      _owner: PromiseOrValue<string>,
      _salt: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    getIdentity(
      _wallet: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getWallets(
      _identity: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    isSaltTaken(
      _salt: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    isTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    linkWallet(
      _newWallet: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    removeTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    unlinkWallet(
      _oldWallet: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    addTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    createIdentity(
      _wallet: PromiseOrValue<string>,
      _salt: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    createTokenIdentity(
      _token: PromiseOrValue<string>,
      _owner: PromiseOrValue<string>,
      _salt: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    getIdentity(
      _wallet: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getWallets(
      _identity: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    isSaltTaken(
      _salt: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    isTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    linkWallet(
      _newWallet: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    removeTokenFactory(
      _factory: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    unlinkWallet(
      _oldWallet: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;
  };
}
