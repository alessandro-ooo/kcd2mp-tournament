import { useForm, type SubmitHandler } from "react-hook-form";
import Number from "./inputs/number";

const DuelSettingsForm = () => {
  type DuelSettingsFormT = {
    time: number;
    useOwnWeapons: boolean;
  };

  const {
    register,
    handleSubmit,
  } = useForm<DuelSettingsFormT>({
    defaultValues: {
      time: 60,
      useOwnWeapons: false,
    },
  });
  const onSubmit: SubmitHandler<DuelSettingsFormT> = (data) =>
    console.log(data);

  return (
    <div className="flex flex-col gap-4">
      <p>Duel Settings</p>
      <form onSubmit={handleSubmit(onSubmit)} className="flex flex-col gap-4">
        <Number
          label="Time"
          {...register("time", { valueAsNumber: true })}
          onLeftArrowClick={() => {}}
          onRightArrowClick={() => {}}
        />

        <input type="checkbox" {...register("useOwnWeapons")} />
        <label>Use Own Weapons</label>
        <button
          type="button"
          onClick={() =>
            KcdMp.emitServer("panel.duelsettings.start", "start").catch((error) =>
              KcdMp.log.warn(`panel.duelsettings.start: ${error.message}`),
            )
          }
        >
          start
        </button>
      </form>
    </div>
  );
};

export default DuelSettingsForm;
