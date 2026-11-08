import { useForm } from "react-hook-form";
import Number from "./inputs/number";
import Checkbox from "./inputs/checkbox";
import DialogBody from "../dialog/dialogbody";
import Button from "./inputs/button";
import DialogElo from "../dialog/dialogelo";
import DialogPlayers from "../dialog/dialogplayers";
import weapons from "../../../utils/melee.json";
import shields from "../../../utils/shields.json";
import Select from "./inputs/select";

type DuelSettingsForm = {
  player: {
    name: string;
    elo: number;
  };
  nearbyPlayers: { pid: number; name: string; elo: number }[];
};

const DuelSettingsForm = ({ player, nearbyPlayers }: DuelSettingsForm) => {
  type FormData = {
    time: number;
    useOwnWeapons: boolean;
    isRanked: boolean;
    numberOfRounds: number;
    weaponId?: string;
    shieldId?: string;
    nearbyPlayers: {
      pid: number;
      name: string;
      elo: number;
    }[];
    selectedPlayer: {
      pid: number;
      name: string;
      elo: number;
    };
  };

  const {
    register,
    watch,
    setValue,

    formState: { isValid },
  } = useForm<FormData>({
    defaultValues: {
      time: 60,
      useOwnWeapons: false,
      isRanked: false,
      numberOfRounds: 1,
    },
  });

  const watchisRanked = watch("isRanked");
  const watchIsOwnWeapons = watch("useOwnWeapons");
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
            max: 4,
          })}
          onLeftArrowClick={() => {}}
          onRightArrowClick={() => {}}
        />

        <div className="flex flex-col gap-2">
          <Checkbox label="Use own weapons" {...register("useOwnWeapons")} />
          {/* <Checkbox label="Ranked duel" {...register("isRanked")} /> */}
        </div>

        {!watchIsOwnWeapons && (
          <div className="flex flex-col gap-2">
            {" "}
            <Select
              {...register("weaponId", {
                setValueAs: (value) => (value === "" ? undefined : value),
              })}
              label="Weapon"
              selected={{ name: "Fists", value: "" }}
              items={[
                { name: "Fists", value: "" },
                ...weapons.map((weapon) => ({
                  name: weapon.englishName || weapon.name,
                  value: weapon.name,
                })),
              ]}
            />
            <Select
              {...register("shieldId", {
                setValueAs: (value) => (value === "" ? undefined : value),
              })}
              label="Shield"
              selected={{ name: "No shield", value: "" }}
              items={[
                { name: "No shield", value: "" },
                ...shields.map((shield) => ({
                  name: shield.englishName || shield.name,
                  value: shield.name,
                })),
              ]}
            />
          </div>
        )}

        <DialogPlayers
          onPlayerClick={(selectedPlayer) =>
            setValue("selectedPlayer", selectedPlayer)
          }
          nearbyPlayers={nearbyPlayers}
          selected={watch("selectedPlayer")}
        ></DialogPlayers>

        {watchisRanked && !!watchSelectedPlayer && (
          <div className="hidden">
            {/* TODO: ELO */}
            <DialogElo
              playerOne={player}
              playerTwo={{
                name: watchSelectedPlayer.name,
                elo: watchSelectedPlayer.elo,
              }}
            />
          </div>
        )}
        <Button
          disabled={!isInviteValid}
          type="button"
          onClick={() => {
            KcdMp.emitServer("panel.frontend.duel.sendinvite", {
              ...watch(),
              selectedPlayer: watchSelectedPlayer,
            }).catch((error) =>
              KcdMp.log.warn(
                `panel.frontend.duel.sendinvite: ${error.message}`,
              ),
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
