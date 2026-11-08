import { cn } from "../../../utils/cn";
import DialogBody from "../dialog/dialogbody";
import Button from "./inputs/button";
import weapons from "../../../utils/melee.json";
import shields from "../../../utils/shields.json";

type DuelInviteFormProps = {
  isRanked: boolean;
  opponent: { name: string; elo: number };
  numbersOfRounds: number;
  time: number;
  useOwnWeapons: boolean;
  weaponId?: string;
  shieldId?: string;
  onAccept: () => void;
  onDecline: () => void;
};

const DuelInviteForm = ({
  isRanked,
  opponent,
  numbersOfRounds,
  time,
  useOwnWeapons,
  weaponId,
  shieldId,
  onAccept,
  onDecline,
}: DuelInviteFormProps) => {
  const weapon = weapons.find((item) => item.name === weaponId);
  const shield = shields.find((item) => item.name === shieldId);

  return (
    <DialogBody title="You've received an invite to duel">
      <div className="flex flex-col gap-6">
        <div>
          <div className="mb-3 flex items-center justify-between gap-3">
            <h2
              id="invite-details-heading"
              className="text-xs font-bold uppercase tracking-[0.16em] text-[#746751]"
            >
              Match details
            </h2>
            <div
              className={cn(
                "inline-flex items-center rounded-full border px-3 py-1 text-xs font-bold",
                isRanked && "border-[#c99a61] bg-[#f2e4c9] text-[#6d431e]",
                !isRanked && "border-[#c4b596] bg-[#f7f1e3] text-[#625b50]",
              )}
            >
              {isRanked ? "Ranked" : "Casual"}
            </div>
          </div>
          <div className="divide-y divide-[#e4dac7] border-y border-[#c4b596]">
            <div className="flex items-center justify-between gap-4 py-3">
              <div className="text-sm text-[#746751]">Format</div>
              <div className="text-right font-medium">
                {numbersOfRounds === 1
                  ? "One round"
                  : `${numbersOfRounds} rounds`}
              </div>
            </div>
            <div className="flex items-center justify-between gap-4 py-3">
              <div className="text-sm text-[#746751]">Duration</div>
              <div className="text-right font-medium tabular-nums">
                {time} seconds per round
              </div>
            </div>
            <div className="flex items-center justify-between gap-4 py-3">
              <div className="text-sm text-[#746751]">Equipment</div>
              <div className="text-right font-medium">
                {useOwnWeapons
                  ? "Own weapons"
                  : weapon?.englishName || weapon?.name || "Duel equipment"}
              </div>
            </div>
            {shield && (
              <div className="flex items-center justify-between gap-4 py-3">
                <div className="text-sm text-[#746751]">Shield</div>
                <div className="text-right font-medium">
                  {shield.englishName || shield.name}
                </div>
              </div>
            )}
          </div>
        </div>

        <div aria-labelledby="opponent-heading">
          <h2
            id="opponent-heading"
            className="mb-3 text-xs font-bold uppercase tracking-[0.16em] text-[#746751]"
          >
            Your opponent
          </h2>
          <div className="flex items-center gap-4 border border-[#c4b596] bg-[#f7f1e3] p-4">
            <div className="min-w-0 flex-1">
              <p className="truncate text-lg font-medium text-[#121010]">
                {opponent.name}
              </p>
              <p className="text-sm text-[#746751]">Opponent</p>
            </div>
            <div className="shrink-0 border-l border-[#c4b596] pl-4 text-right">
              <p className="text-xs font-bold uppercase tracking-[0.12em] text-[#746751]">
                Elo
              </p>
              <p className="font-display text-2xl tabular-nums text-[#842326]">
                {opponent.elo}
              </p>
            </div>
          </div>
        </div>

        <div className="flex flex-row justify-between">
          <Button type="button" onClick={onAccept}>
            Accept
          </Button>
          <Button variant="secondary" type="button" onClick={onDecline}>
            Decline
          </Button>
        </div>
      </div>
    </DialogBody>
  );
};

export default DuelInviteForm;
