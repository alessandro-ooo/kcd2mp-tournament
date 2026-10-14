import DuelInviteForm from "./components/forms/duel-invite-form";

const DuelInvitePage = () => {
  return (
    <div className="flex px-10 py-10 justify-left text-[#24201d]">
      {" "}
      <DuelInviteForm
        isRanked={true}
        numbersOfRounds={3}
        opponent={{ name: "testbuddy", elo: 100 }}
        time={60}
        useOwnWeapons={true}
      />
    </div>
  );
};

export default DuelInvitePage;
