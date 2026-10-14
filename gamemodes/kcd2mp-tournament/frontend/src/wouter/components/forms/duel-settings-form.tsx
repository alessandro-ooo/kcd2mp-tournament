import { useForm } from "react-hook-form";
import Number from "./inputs/number";
import Checkbox from "./inputs/checkbox";
import DialogBody from "../dialog/dialogbody";
import Button from "./inputs/button";
import DialogElo from "../dialog/dialogelo";
import DialogPlayers from "../dialog/dialogplayers";

type DuelSettingsForm = {
  currentElo: number;
  nearbyPlayers: {
    name: string;
    elo: number;
  }[];
};

const DuelSettingsForm = ({ nearbyPlayers, currentElo }: DuelSettingsForm) => {
  type FormData = {
    time: number;
    useOwnWeapons: boolean;
    isRanked: boolean;
    currentElo?: number;
    numberOfRounds: number;
    nearbyPlayers: {
      name: string;
      elo: number;
    }[];
    selectedPlayer: {
      name: string;
      elo: number;
    };
  };

  const {
    register,
    watch,
    setValue,
    getValues,
    formState: { isValid },
  } = useForm<FormData>({
    defaultValues: {
      time: 60,
      useOwnWeapons: false,
      isRanked: false,
      currentElo: currentElo, // placeholder value, replace with actual current Elo if available
      numberOfRounds: 1,
      nearbyPlayers: nearbyPlayers,
    },
  });

  const watchisRanked = watch("isRanked");
  const getNearbyPlayers = getValues("nearbyPlayers");

  console.log("isValid", isValid);

  const watchSelectedPlayer = watch("selectedPlayer");

  const isInviteValid = !!watchSelectedPlayer && isValid;

  return (
    <DialogBody title="Duel" subtitle="General settings">
      <form className="flex flex-col gap-6">
        <Number
          label="Duration in seconds"
          {...register("time", { valueAsNumber: true })}
          onLeftArrowClick={() => {}}
          onRightArrowClick={() => {}}
        />

        <Number
          label="Number of rounds"
          {...register("numberOfRounds", {
            valueAsNumber: true,
            min: 1,
            max: 3,
          })}
          onLeftArrowClick={() => {}}
          onRightArrowClick={() => {}}
        />

        <div className="flex flex-col gap-2">
          <Checkbox label="Use own weapons" {...register("useOwnWeapons")} />
          <Checkbox label="Ranked duel" {...register("isRanked")} />
        </div>

        <DialogPlayers
          onPlayerClick={(name) => setValue("selectedPlayer", name)}
          nearbyPlayers={getNearbyPlayers}
          selected={watch("selectedPlayer")}
        ></DialogPlayers>

        {watchisRanked && !!watchSelectedPlayer && (
          <>
            <DialogElo
              playerOne={{ name: "Player One", elo: 1000 }}
              playerTwo={{
                name: watchSelectedPlayer.name,
                elo: watchSelectedPlayer.elo,
              }}
            />
          </>
        )}
        <Button
          disabled={!isInviteValid}
          type="button"
          onClick={() => {
            KcdMp.emitServer("panel.duelsettings.start", watch()).catch(
              (error) =>
                KcdMp.log.warn(`panel.duelsettings.start: ${error.message}`),
            );
          }}
        >
          Send duel
        </Button>
      </form>
    </DialogBody>
  );
};

export default DuelSettingsForm;
