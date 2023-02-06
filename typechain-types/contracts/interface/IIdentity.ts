/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import type {
  BaseContract,
  BigNumber,
  BigNumberish,
  BytesLike,
  CallOverrides,
  ContractTransaction,
  Overrides,
  PayableOverrides,
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

export interface IIdentityInterface extends utils.Interface {
  functions: {
    "addClaim(uint256,uint256,address,bytes,bytes,string)": FunctionFragment;
    "addKey(bytes32,uint256,uint256)": FunctionFragment;
    "approve(uint256,bool)": FunctionFragment;
    "execute(address,uint256,bytes)": FunctionFragment;
    "getClaim(bytes32)": FunctionFragment;
    "getClaimIdsByTopic(uint256)": FunctionFragment;
    "getKey(bytes32)": FunctionFragment;
    "getKeyPurposes(bytes32)": FunctionFragment;
    "getKeysByPurpose(uint256)": FunctionFragment;
    "keyHasPurpose(bytes32,uint256)": FunctionFragment;
    "removeClaim(bytes32)": FunctionFragment;
    "removeKey(bytes32,uint256)": FunctionFragment;
  };

  getFunction(
    nameOrSignatureOrTopic:
      | "addClaim"
      | "addKey"
      | "approve"
      | "execute"
      | "getClaim"
      | "getClaimIdsByTopic"
      | "getKey"
      | "getKeyPurposes"
      | "getKeysByPurpose"
      | "keyHasPurpose"
      | "removeClaim"
      | "removeKey"
  ): FunctionFragment;

  encodeFunctionData(
    functionFragment: "addClaim",
    values: [
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<string>,
      PromiseOrValue<BytesLike>,
      PromiseOrValue<BytesLike>,
      PromiseOrValue<string>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "addKey",
    values: [
      PromiseOrValue<BytesLike>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BigNumberish>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "approve",
    values: [PromiseOrValue<BigNumberish>, PromiseOrValue<boolean>]
  ): string;
  encodeFunctionData(
    functionFragment: "execute",
    values: [
      PromiseOrValue<string>,
      PromiseOrValue<BigNumberish>,
      PromiseOrValue<BytesLike>
    ]
  ): string;
  encodeFunctionData(
    functionFragment: "getClaim",
    values: [PromiseOrValue<BytesLike>]
  ): string;
  encodeFunctionData(
    functionFragment: "getClaimIdsByTopic",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "getKey",
    values: [PromiseOrValue<BytesLike>]
  ): string;
  encodeFunctionData(
    functionFragment: "getKeyPurposes",
    values: [PromiseOrValue<BytesLike>]
  ): string;
  encodeFunctionData(
    functionFragment: "getKeysByPurpose",
    values: [PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "keyHasPurpose",
    values: [PromiseOrValue<BytesLike>, PromiseOrValue<BigNumberish>]
  ): string;
  encodeFunctionData(
    functionFragment: "removeClaim",
    values: [PromiseOrValue<BytesLike>]
  ): string;
  encodeFunctionData(
    functionFragment: "removeKey",
    values: [PromiseOrValue<BytesLike>, PromiseOrValue<BigNumberish>]
  ): string;

  decodeFunctionResult(functionFragment: "addClaim", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "addKey", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "approve", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "execute", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "getClaim", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getClaimIdsByTopic",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "getKey", data: BytesLike): Result;
  decodeFunctionResult(
    functionFragment: "getKeyPurposes",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "getKeysByPurpose",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "keyHasPurpose",
    data: BytesLike
  ): Result;
  decodeFunctionResult(
    functionFragment: "removeClaim",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "removeKey", data: BytesLike): Result;

  events: {
    "Approved(uint256,bool)": EventFragment;
    "ClaimAdded(bytes32,uint256,uint256,address,bytes,bytes,string)": EventFragment;
    "ClaimChanged(bytes32,uint256,uint256,address,bytes,bytes,string)": EventFragment;
    "ClaimRemoved(bytes32,uint256,uint256,address,bytes,bytes,string)": EventFragment;
    "ClaimRequested(uint256,uint256,uint256,address,bytes,bytes,string)": EventFragment;
    "Executed(uint256,address,uint256,bytes)": EventFragment;
    "ExecutionFailed(uint256,address,uint256,bytes)": EventFragment;
    "ExecutionRequested(uint256,address,uint256,bytes)": EventFragment;
    "KeyAdded(bytes32,uint256,uint256)": EventFragment;
    "KeyRemoved(bytes32,uint256,uint256)": EventFragment;
    "KeysRequiredChanged(uint256,uint256)": EventFragment;
  };

  getEvent(nameOrSignatureOrTopic: "Approved"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "ClaimAdded"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "ClaimChanged"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "ClaimRemoved"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "ClaimRequested"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "Executed"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "ExecutionFailed"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "ExecutionRequested"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "KeyAdded"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "KeyRemoved"): EventFragment;
  getEvent(nameOrSignatureOrTopic: "KeysRequiredChanged"): EventFragment;
}

export interface ApprovedEventObject {
  executionId: BigNumber;
  approved: boolean;
}
export type ApprovedEvent = TypedEvent<
  [BigNumber, boolean],
  ApprovedEventObject
>;

export type ApprovedEventFilter = TypedEventFilter<ApprovedEvent>;

export interface ClaimAddedEventObject {
  claimId: string;
  topic: BigNumber;
  scheme: BigNumber;
  issuer: string;
  signature: string;
  data: string;
  uri: string;
}
export type ClaimAddedEvent = TypedEvent<
  [string, BigNumber, BigNumber, string, string, string, string],
  ClaimAddedEventObject
>;

export type ClaimAddedEventFilter = TypedEventFilter<ClaimAddedEvent>;

export interface ClaimChangedEventObject {
  claimId: string;
  topic: BigNumber;
  scheme: BigNumber;
  issuer: string;
  signature: string;
  data: string;
  uri: string;
}
export type ClaimChangedEvent = TypedEvent<
  [string, BigNumber, BigNumber, string, string, string, string],
  ClaimChangedEventObject
>;

export type ClaimChangedEventFilter = TypedEventFilter<ClaimChangedEvent>;

export interface ClaimRemovedEventObject {
  claimId: string;
  topic: BigNumber;
  scheme: BigNumber;
  issuer: string;
  signature: string;
  data: string;
  uri: string;
}
export type ClaimRemovedEvent = TypedEvent<
  [string, BigNumber, BigNumber, string, string, string, string],
  ClaimRemovedEventObject
>;

export type ClaimRemovedEventFilter = TypedEventFilter<ClaimRemovedEvent>;

export interface ClaimRequestedEventObject {
  claimRequestId: BigNumber;
  topic: BigNumber;
  scheme: BigNumber;
  issuer: string;
  signature: string;
  data: string;
  uri: string;
}
export type ClaimRequestedEvent = TypedEvent<
  [BigNumber, BigNumber, BigNumber, string, string, string, string],
  ClaimRequestedEventObject
>;

export type ClaimRequestedEventFilter = TypedEventFilter<ClaimRequestedEvent>;

export interface ExecutedEventObject {
  executionId: BigNumber;
  to: string;
  value: BigNumber;
  data: string;
}
export type ExecutedEvent = TypedEvent<
  [BigNumber, string, BigNumber, string],
  ExecutedEventObject
>;

export type ExecutedEventFilter = TypedEventFilter<ExecutedEvent>;

export interface ExecutionFailedEventObject {
  executionId: BigNumber;
  to: string;
  value: BigNumber;
  data: string;
}
export type ExecutionFailedEvent = TypedEvent<
  [BigNumber, string, BigNumber, string],
  ExecutionFailedEventObject
>;

export type ExecutionFailedEventFilter = TypedEventFilter<ExecutionFailedEvent>;

export interface ExecutionRequestedEventObject {
  executionId: BigNumber;
  to: string;
  value: BigNumber;
  data: string;
}
export type ExecutionRequestedEvent = TypedEvent<
  [BigNumber, string, BigNumber, string],
  ExecutionRequestedEventObject
>;

export type ExecutionRequestedEventFilter =
  TypedEventFilter<ExecutionRequestedEvent>;

export interface KeyAddedEventObject {
  key: string;
  purpose: BigNumber;
  keyType: BigNumber;
}
export type KeyAddedEvent = TypedEvent<
  [string, BigNumber, BigNumber],
  KeyAddedEventObject
>;

export type KeyAddedEventFilter = TypedEventFilter<KeyAddedEvent>;

export interface KeyRemovedEventObject {
  key: string;
  purpose: BigNumber;
  keyType: BigNumber;
}
export type KeyRemovedEvent = TypedEvent<
  [string, BigNumber, BigNumber],
  KeyRemovedEventObject
>;

export type KeyRemovedEventFilter = TypedEventFilter<KeyRemovedEvent>;

export interface KeysRequiredChangedEventObject {
  purpose: BigNumber;
  number: BigNumber;
}
export type KeysRequiredChangedEvent = TypedEvent<
  [BigNumber, BigNumber],
  KeysRequiredChangedEventObject
>;

export type KeysRequiredChangedEventFilter =
  TypedEventFilter<KeysRequiredChangedEvent>;

export interface IIdentity extends BaseContract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  interface: IIdentityInterface;

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
    addClaim(
      _topic: PromiseOrValue<BigNumberish>,
      _scheme: PromiseOrValue<BigNumberish>,
      issuer: PromiseOrValue<string>,
      _signature: PromiseOrValue<BytesLike>,
      _data: PromiseOrValue<BytesLike>,
      _uri: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    addKey(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      _keyType: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    approve(
      _id: PromiseOrValue<BigNumberish>,
      _approve: PromiseOrValue<boolean>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    execute(
      _to: PromiseOrValue<string>,
      _value: PromiseOrValue<BigNumberish>,
      _data: PromiseOrValue<BytesLike>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    getClaim(
      _claimId: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber, string, string, string, string] & {
        topic: BigNumber;
        scheme: BigNumber;
        issuer: string;
        signature: string;
        data: string;
        uri: string;
      }
    >;

    getClaimIdsByTopic(
      _topic: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[string[]] & { claimIds: string[] }>;

    getKey(
      _key: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber[], BigNumber, string] & {
        purposes: BigNumber[];
        keyType: BigNumber;
        key: string;
      }
    >;

    getKeyPurposes(
      _key: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<[BigNumber[]] & { _purposes: BigNumber[] }>;

    getKeysByPurpose(
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[string[]] & { keys: string[] }>;

    keyHasPurpose(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<[boolean] & { exists: boolean }>;

    removeClaim(
      _claimId: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;

    removeKey(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<ContractTransaction>;
  };

  addClaim(
    _topic: PromiseOrValue<BigNumberish>,
    _scheme: PromiseOrValue<BigNumberish>,
    issuer: PromiseOrValue<string>,
    _signature: PromiseOrValue<BytesLike>,
    _data: PromiseOrValue<BytesLike>,
    _uri: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  addKey(
    _key: PromiseOrValue<BytesLike>,
    _purpose: PromiseOrValue<BigNumberish>,
    _keyType: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  approve(
    _id: PromiseOrValue<BigNumberish>,
    _approve: PromiseOrValue<boolean>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  execute(
    _to: PromiseOrValue<string>,
    _value: PromiseOrValue<BigNumberish>,
    _data: PromiseOrValue<BytesLike>,
    overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  getClaim(
    _claimId: PromiseOrValue<BytesLike>,
    overrides?: CallOverrides
  ): Promise<
    [BigNumber, BigNumber, string, string, string, string] & {
      topic: BigNumber;
      scheme: BigNumber;
      issuer: string;
      signature: string;
      data: string;
      uri: string;
    }
  >;

  getClaimIdsByTopic(
    _topic: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<string[]>;

  getKey(
    _key: PromiseOrValue<BytesLike>,
    overrides?: CallOverrides
  ): Promise<
    [BigNumber[], BigNumber, string] & {
      purposes: BigNumber[];
      keyType: BigNumber;
      key: string;
    }
  >;

  getKeyPurposes(
    _key: PromiseOrValue<BytesLike>,
    overrides?: CallOverrides
  ): Promise<BigNumber[]>;

  getKeysByPurpose(
    _purpose: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<string[]>;

  keyHasPurpose(
    _key: PromiseOrValue<BytesLike>,
    _purpose: PromiseOrValue<BigNumberish>,
    overrides?: CallOverrides
  ): Promise<boolean>;

  removeClaim(
    _claimId: PromiseOrValue<BytesLike>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  removeKey(
    _key: PromiseOrValue<BytesLike>,
    _purpose: PromiseOrValue<BigNumberish>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<ContractTransaction>;

  callStatic: {
    addClaim(
      _topic: PromiseOrValue<BigNumberish>,
      _scheme: PromiseOrValue<BigNumberish>,
      issuer: PromiseOrValue<string>,
      _signature: PromiseOrValue<BytesLike>,
      _data: PromiseOrValue<BytesLike>,
      _uri: PromiseOrValue<string>,
      overrides?: CallOverrides
    ): Promise<string>;

    addKey(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      _keyType: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<boolean>;

    approve(
      _id: PromiseOrValue<BigNumberish>,
      _approve: PromiseOrValue<boolean>,
      overrides?: CallOverrides
    ): Promise<boolean>;

    execute(
      _to: PromiseOrValue<string>,
      _value: PromiseOrValue<BigNumberish>,
      _data: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getClaim(
      _claimId: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber, BigNumber, string, string, string, string] & {
        topic: BigNumber;
        scheme: BigNumber;
        issuer: string;
        signature: string;
        data: string;
        uri: string;
      }
    >;

    getClaimIdsByTopic(
      _topic: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<string[]>;

    getKey(
      _key: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<
      [BigNumber[], BigNumber, string] & {
        purposes: BigNumber[];
        keyType: BigNumber;
        key: string;
      }
    >;

    getKeyPurposes(
      _key: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<BigNumber[]>;

    getKeysByPurpose(
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<string[]>;

    keyHasPurpose(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<boolean>;

    removeClaim(
      _claimId: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<boolean>;

    removeKey(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<boolean>;
  };

  filters: {
    "Approved(uint256,bool)"(
      executionId?: PromiseOrValue<BigNumberish> | null,
      approved?: null
    ): ApprovedEventFilter;
    Approved(
      executionId?: PromiseOrValue<BigNumberish> | null,
      approved?: null
    ): ApprovedEventFilter;

    "ClaimAdded(bytes32,uint256,uint256,address,bytes,bytes,string)"(
      claimId?: PromiseOrValue<BytesLike> | null,
      topic?: PromiseOrValue<BigNumberish> | null,
      scheme?: null,
      issuer?: PromiseOrValue<string> | null,
      signature?: null,
      data?: null,
      uri?: null
    ): ClaimAddedEventFilter;
    ClaimAdded(
      claimId?: PromiseOrValue<BytesLike> | null,
      topic?: PromiseOrValue<BigNumberish> | null,
      scheme?: null,
      issuer?: PromiseOrValue<string> | null,
      signature?: null,
      data?: null,
      uri?: null
    ): ClaimAddedEventFilter;

    "ClaimChanged(bytes32,uint256,uint256,address,bytes,bytes,string)"(
      claimId?: PromiseOrValue<BytesLike> | null,
      topic?: PromiseOrValue<BigNumberish> | null,
      scheme?: null,
      issuer?: PromiseOrValue<string> | null,
      signature?: null,
      data?: null,
      uri?: null
    ): ClaimChangedEventFilter;
    ClaimChanged(
      claimId?: PromiseOrValue<BytesLike> | null,
      topic?: PromiseOrValue<BigNumberish> | null,
      scheme?: null,
      issuer?: PromiseOrValue<string> | null,
      signature?: null,
      data?: null,
      uri?: null
    ): ClaimChangedEventFilter;

    "ClaimRemoved(bytes32,uint256,uint256,address,bytes,bytes,string)"(
      claimId?: PromiseOrValue<BytesLike> | null,
      topic?: PromiseOrValue<BigNumberish> | null,
      scheme?: null,
      issuer?: PromiseOrValue<string> | null,
      signature?: null,
      data?: null,
      uri?: null
    ): ClaimRemovedEventFilter;
    ClaimRemoved(
      claimId?: PromiseOrValue<BytesLike> | null,
      topic?: PromiseOrValue<BigNumberish> | null,
      scheme?: null,
      issuer?: PromiseOrValue<string> | null,
      signature?: null,
      data?: null,
      uri?: null
    ): ClaimRemovedEventFilter;

    "ClaimRequested(uint256,uint256,uint256,address,bytes,bytes,string)"(
      claimRequestId?: PromiseOrValue<BigNumberish> | null,
      topic?: PromiseOrValue<BigNumberish> | null,
      scheme?: null,
      issuer?: PromiseOrValue<string> | null,
      signature?: null,
      data?: null,
      uri?: null
    ): ClaimRequestedEventFilter;
    ClaimRequested(
      claimRequestId?: PromiseOrValue<BigNumberish> | null,
      topic?: PromiseOrValue<BigNumberish> | null,
      scheme?: null,
      issuer?: PromiseOrValue<string> | null,
      signature?: null,
      data?: null,
      uri?: null
    ): ClaimRequestedEventFilter;

    "Executed(uint256,address,uint256,bytes)"(
      executionId?: PromiseOrValue<BigNumberish> | null,
      to?: PromiseOrValue<string> | null,
      value?: PromiseOrValue<BigNumberish> | null,
      data?: null
    ): ExecutedEventFilter;
    Executed(
      executionId?: PromiseOrValue<BigNumberish> | null,
      to?: PromiseOrValue<string> | null,
      value?: PromiseOrValue<BigNumberish> | null,
      data?: null
    ): ExecutedEventFilter;

    "ExecutionFailed(uint256,address,uint256,bytes)"(
      executionId?: PromiseOrValue<BigNumberish> | null,
      to?: PromiseOrValue<string> | null,
      value?: PromiseOrValue<BigNumberish> | null,
      data?: null
    ): ExecutionFailedEventFilter;
    ExecutionFailed(
      executionId?: PromiseOrValue<BigNumberish> | null,
      to?: PromiseOrValue<string> | null,
      value?: PromiseOrValue<BigNumberish> | null,
      data?: null
    ): ExecutionFailedEventFilter;

    "ExecutionRequested(uint256,address,uint256,bytes)"(
      executionId?: PromiseOrValue<BigNumberish> | null,
      to?: PromiseOrValue<string> | null,
      value?: PromiseOrValue<BigNumberish> | null,
      data?: null
    ): ExecutionRequestedEventFilter;
    ExecutionRequested(
      executionId?: PromiseOrValue<BigNumberish> | null,
      to?: PromiseOrValue<string> | null,
      value?: PromiseOrValue<BigNumberish> | null,
      data?: null
    ): ExecutionRequestedEventFilter;

    "KeyAdded(bytes32,uint256,uint256)"(
      key?: PromiseOrValue<BytesLike> | null,
      purpose?: PromiseOrValue<BigNumberish> | null,
      keyType?: PromiseOrValue<BigNumberish> | null
    ): KeyAddedEventFilter;
    KeyAdded(
      key?: PromiseOrValue<BytesLike> | null,
      purpose?: PromiseOrValue<BigNumberish> | null,
      keyType?: PromiseOrValue<BigNumberish> | null
    ): KeyAddedEventFilter;

    "KeyRemoved(bytes32,uint256,uint256)"(
      key?: PromiseOrValue<BytesLike> | null,
      purpose?: PromiseOrValue<BigNumberish> | null,
      keyType?: PromiseOrValue<BigNumberish> | null
    ): KeyRemovedEventFilter;
    KeyRemoved(
      key?: PromiseOrValue<BytesLike> | null,
      purpose?: PromiseOrValue<BigNumberish> | null,
      keyType?: PromiseOrValue<BigNumberish> | null
    ): KeyRemovedEventFilter;

    "KeysRequiredChanged(uint256,uint256)"(
      purpose?: null,
      number?: null
    ): KeysRequiredChangedEventFilter;
    KeysRequiredChanged(
      purpose?: null,
      number?: null
    ): KeysRequiredChangedEventFilter;
  };

  estimateGas: {
    addClaim(
      _topic: PromiseOrValue<BigNumberish>,
      _scheme: PromiseOrValue<BigNumberish>,
      issuer: PromiseOrValue<string>,
      _signature: PromiseOrValue<BytesLike>,
      _data: PromiseOrValue<BytesLike>,
      _uri: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    addKey(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      _keyType: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    approve(
      _id: PromiseOrValue<BigNumberish>,
      _approve: PromiseOrValue<boolean>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    execute(
      _to: PromiseOrValue<string>,
      _value: PromiseOrValue<BigNumberish>,
      _data: PromiseOrValue<BytesLike>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    getClaim(
      _claimId: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getClaimIdsByTopic(
      _topic: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getKey(
      _key: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getKeyPurposes(
      _key: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    getKeysByPurpose(
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    keyHasPurpose(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    removeClaim(
      _claimId: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;

    removeKey(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    addClaim(
      _topic: PromiseOrValue<BigNumberish>,
      _scheme: PromiseOrValue<BigNumberish>,
      issuer: PromiseOrValue<string>,
      _signature: PromiseOrValue<BytesLike>,
      _data: PromiseOrValue<BytesLike>,
      _uri: PromiseOrValue<string>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    addKey(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      _keyType: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    approve(
      _id: PromiseOrValue<BigNumberish>,
      _approve: PromiseOrValue<boolean>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    execute(
      _to: PromiseOrValue<string>,
      _value: PromiseOrValue<BigNumberish>,
      _data: PromiseOrValue<BytesLike>,
      overrides?: PayableOverrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    getClaim(
      _claimId: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getClaimIdsByTopic(
      _topic: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getKey(
      _key: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getKeyPurposes(
      _key: PromiseOrValue<BytesLike>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    getKeysByPurpose(
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    keyHasPurpose(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    removeClaim(
      _claimId: PromiseOrValue<BytesLike>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;

    removeKey(
      _key: PromiseOrValue<BytesLike>,
      _purpose: PromiseOrValue<BigNumberish>,
      overrides?: Overrides & { from?: PromiseOrValue<string> }
    ): Promise<PopulatedTransaction>;
  };
}
