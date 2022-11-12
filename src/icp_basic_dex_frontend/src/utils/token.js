import {
  canisterId as GoldDIP20canisterId,
  createActor as GoldDIP20CreateActor,
  GoldDIP20
} from '../../../declarations/GoldDIP20';
import {
  canisterId as SilverDIP20canisterId,
  createActor as SilverDIP20CreateActor,
  SilverDIP20
} from '../../../declarations/SilverDIP20';

// DEX上で扱うトークンのデータを配列に格納
export const tokens = [
  {
    canisterName: 'GoldDIP20',
    canister: GoldDIP20,
    tokenSymbol: 'TGLD',
    createActor: GoldDIP20CreateActor,
    canisterId: GoldDIP20canisterId,
  },
  {
    canisterName: 'SilverDIP20',
    canister: SilverDIP20,
    tokenSymbol: 'TSLV',
    createActor: SilverDIP20CreateActor,
    canisterId: SilverDIP20canisterId,
  },
];