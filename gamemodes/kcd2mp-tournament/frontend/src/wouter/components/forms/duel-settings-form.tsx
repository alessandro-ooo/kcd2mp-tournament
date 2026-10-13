import { useForm } from "react-hook-form";
import Number from "./inputs/number";
import Checkbox from "./inputs/checkbox";
import DialogBody from "../dialog/dialogbody";
import Button from "./inputs/button";
import DialogElo from "../dialog/dialogelo";

const DuelSettingsForm = () => {
  type DuelSettingsFormT = {
    time: number;
    useOwnWeapons: boolean;
    isRanked: boolean;
    currentElo?: number;
    opponentElo?: number;
    numberOfRounds: number;
  };

  const { register, watch } = useForm<DuelSettingsFormT>({
    defaultValues: {
      time: 60,
      useOwnWeapons: false,
      isRanked: false,
      currentElo: 1000, // placeholder value, replace with actual current Elo if available
      opponentElo: 1000, // placeholder value, replace with actual opponent Elo if available
      numberOfRounds: 1,
    },
  });

  // const onSubmit: SubmitHandler<DuelSettingsFormT> = (data) => {
  //   KcdMp.emitServer("panel.duelsettings.start", data).catch((error) =>
  //     KcdMp.log.warn(`panel.duelsettings.start: ${error.message}`),
  //   );
  //   return;
  // };

  const watchisRanked = watch("isRanked");

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

        {watchisRanked && (
          <>
            {" "}
            <div className="border-b border-[#c4b596] pb-5">
              <h1 className="font-display text-3xl text-[#121010] sm:text-4xl">
                Ranked information
              </h1>
            </div>
            <DialogElo
              playerOne={{ name: "Player One", elo: 1000 }}
              playerTwo={{ name: "Player Two", elo: 1000 }}
            />
          </>
        )}
        <Button
          type="button"
          onClick={() => {
            KcdMp.emitServer("panel.duelsettings.start", watch()).catch(
              (error) =>
                KcdMp.log.warn(`panel.duelsettings.start: ${error.message}`),
            );
          }}
        >
          Start duel
        </Button>
      </form>
    </DialogBody>
  );
};

export default DuelSettingsForm;
