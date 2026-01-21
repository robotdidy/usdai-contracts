import { BigInt, Bytes } from "@graphprotocol/graph-ts";
import { Transfer as TransferEvent } from "../generated/USDai/USDai";
import { USDaiStats } from "../generated/schema";

const STATS_ID = Bytes.fromUTF8("stats");

export function handleTransfer(event: TransferEvent): void {
  let stats = USDaiStats.load(STATS_ID);

  if (stats == null) {
    stats = new USDaiStats(STATS_ID);
    stats.totalVolume = BigInt.fromI32(0);
    stats.transferCount = BigInt.fromI32(0);
  }

  stats.totalVolume = stats.totalVolume.plus(event.params.value);
  stats.transferCount = stats.transferCount.plus(BigInt.fromI32(1));
  stats.save();
}
