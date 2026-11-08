import H1 from "../typography/header";

type DialogEloProps = {
  playerOne: {
    name: string;
    elo: number;
  };

  playerTwo: {
    name: string;
    elo: number;
  };
};

const DialogElo = ({ playerOne, playerTwo }: DialogEloProps) => {
  return (
    <div className="flex flex-col gap-4">
      <H1>Ranked informatiom</H1>
      <div className="flex flex-row gap-4 justify-between">
        <div className="flex flex-col gap-1 items-center">
          <p className="font-bold text-[#861d1c]">{playerOne.name}</p>
          <p>{playerOne.elo}</p>
        </div>
        <div className="flex flex-col gap-1 items-center">
          <p className="font-bold text-[#1c4686]">{playerTwo.name}</p>
          <p>{playerTwo.elo}</p>
        </div>
      </div>
    </div>
  );
};

export default DialogElo;
