import DuelSettingsForm from "./components/forms/duel-settings-form";

const DuelSettingsPage = () => {
  return (
    <div className="flex px-10 py-10 justify-left text-[#24201d]">
      <DuelSettingsForm
        currentElo={100}
        nearbyPlayers={[
          { name: "Alessandro Buonocore", elo: 100 },
          { name: "Marco Rossi", elo: 500 },
        ]}
      />
    </div>
  );
};

export default DuelSettingsPage;
