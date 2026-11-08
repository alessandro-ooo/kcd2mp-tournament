import { cn } from "../../../utils/cn";
import H1 from "../typography/header";

type DialogPlayersProps = {
  nearbyPlayers: { pid: number; name: string; elo: number }[];
  selected?: {
    pid: number;
    name: string;
    elo: number;
  };
  onPlayerClick: (player: { pid: number; name: string; elo: number }) => void;
};

const DialogPlayers = ({
  nearbyPlayers,
  selected,
  onPlayerClick,
}: DialogPlayersProps) => {
  return (
    <div className="flex flex-col gap-4 justify-between">
      <H1>Available players</H1>
      <div className="flex flex-col gap-2">
        {" "}
        {nearbyPlayers.map((player) => (
          <button
            key={player.pid}
            type="button"
            className={cn(
              "text-[#121010] hover:text-[#842326] hover:cursor-pointer w-full text-left h-8",
              !!selected &&
                selected.name === player.name &&
                "text-[#842326] font-semibold",
            )}
            onClick={() => onPlayerClick(player)}
          >
            {player.name} - {player.elo} elo
          </button>
        ))}
      </div>
    </div>
  );
};

export default DialogPlayers;
