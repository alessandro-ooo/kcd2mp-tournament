import { useEffect, useState } from "react";
import DuelInviteForm from "./components/forms/duel-invite-form";

type InviteData = {
  opponent: { name: string; elo: number };
  settings: {
    isRanked: boolean;
    numberOfRounds: number;
    time: number;
    useOwnWeapons: boolean;
    weaponId?: string;
    shieldId?: string;
  };
};

const DuelInvitePage = () => {
  const [invite, setInvite] = useState<InviteData>({
    opponent: { name: "", elo: 0 },
    settings: {
      isRanked: false,
      numberOfRounds: 1,
      time: 60,
      useOwnWeapons: false,
      weaponId: "fist",
      shieldId: "fist",
    },
  });

  useEffect(() => {
    const unsubscribe = KcdMp.onServer(
      "panel.frontend.invite.fetch.sendresponse",
      (value) => setInvite(value as InviteData),
    );

    void KcdMp.emitServer("panel.frontend.invite.fetch", {});

    return unsubscribe;
  }, []);

  const onInviteButtonClick = (action: "decline" | "accept") => {
    const emit = "panel.frontend.invite." + action;
    void KcdMp.emitServer(emit, {});
    return;
  };

  return (
    <div className="flex px-10 py-10 justify-left text-[#24201d]">
      <DuelInviteForm
        isRanked={invite.settings.isRanked}
        numbersOfRounds={invite.settings.numberOfRounds}
        opponent={invite.opponent}
        time={invite.settings.time}
        useOwnWeapons={invite.settings.useOwnWeapons}
        weaponId={invite.settings.weaponId}
        shieldId={invite.settings.shieldId}
        onAccept={() => onInviteButtonClick("accept")}
        onDecline={() => onInviteButtonClick("decline")}
      />
    </div>
  );
};

export default DuelInvitePage;
