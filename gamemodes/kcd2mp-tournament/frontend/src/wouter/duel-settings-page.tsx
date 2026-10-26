// import DuelSettingsForm from "./components/forms/duel-settings-form";
import { useEffect, useState } from "react";
import DuelSettingsForm from "./components/forms/duel-settings-form";

const DuelSettingsPage = () => {
  type DuelData = {
    player: { name: string; elo: number };
    nearbyPlayers: { pid: number; name: string; elo: number }[];
  };

  const [duelData, setDuelData] = useState<DuelData>({
    player: {
      name: "",
      elo: 0,
    },
    nearbyPlayers: [],
  });

  useEffect(() => {
    const unsubscribe = KcdMp.onServer(
      "panel.frontend.duel.fetch.sendresponse",
      (value) => setDuelData(value as DuelData),
    );

    void KcdMp.emitServer("panel.frontend.duel.fetch", {});

    return unsubscribe;
  }, []);

  console.log(duelData);

  return (
    <div className="flex px-10 py-10 justify-left text-[#24201d]">
      <DuelSettingsForm
        player={duelData.player}
        nearbyPlayers={duelData.nearbyPlayers}
      />
    </div>
  );
};

export default DuelSettingsPage;
