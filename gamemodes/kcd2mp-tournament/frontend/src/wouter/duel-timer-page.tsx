import { useEffect, useRef, useState } from "react";

const DuelTimerPage = () => {
  type RoundType = {
    outcome: "matchWon" | "matchLost" | "matchDraw" | "roundWon" | "roundLost";
    round: number;
  };

  type TimerData = {
    settings: {
      isRanked: boolean;
      numberOfRounds: number;
      time: number;
      useOwnWeapons: boolean;
      weaponId?: string;
      shieldId?: string;
    };
  };

  const [timer, setTimer] = useState<number>(0);
  const [ongoing, setOngoing] = useState<boolean>(false);
  const [roundResult, setRoundResult] = useState<RoundType | undefined>();
  const [isResultVisible, setIsResultVisible] = useState(false);
  const resultTimeout = useRef<number | undefined>(undefined);
  const tieSent = useRef(false);
  const [isTie, setIsTie] = useState(false);

  useEffect(() => {
    const unsubscribe = KcdMp.onServer("panel.frontend.timer.send", (value) => {
      const data = value as TimerData;
      tieSent.current = false;
      setIsTie(false);
      setRoundResult(undefined);
      setIsResultVisible(false);
      if (resultTimeout.current !== undefined) {
        window.clearTimeout(resultTimeout.current);
        resultTimeout.current = undefined;
      }
      setOngoing(true);
      setTimer(data.settings.time);
    });

    return unsubscribe;
  }, []);

  useEffect(() => {
    if (!ongoing || roundResult) return;

    const interval = window.setInterval(() => {
      setTimer((currentTimer) => Math.max(currentTimer - 1, 0));
    }, 1000);

    return () => window.clearInterval(interval);
  }, [ongoing, roundResult]);

  useEffect(() => {
    if (!ongoing || timer > 0 || roundResult || tieSent.current) return;

    tieSent.current = true;
    setOngoing(false);
    setIsTie(true);
    void KcdMp.emitServer("panel.frontend.duel.result.tie", {});
  }, [ongoing, roundResult, timer]);

  useEffect(() => {
    const unsubscribe = KcdMp.onServer(
      "panel.frontend.duel.round.result",
      (value) => {
        const data = value as RoundType;
        setOngoing(false);
        setRoundResult(data);
        setIsResultVisible(true);

        if (resultTimeout.current !== undefined) {
          window.clearTimeout(resultTimeout.current);
        }

        resultTimeout.current = window.setTimeout(() => {
          setIsResultVisible(false);
          resultTimeout.current = undefined;
        }, 4000);
      },
    );

    return () => {
      unsubscribe();
      if (resultTimeout.current !== undefined) {
        window.clearTimeout(resultTimeout.current);
      }
    };
  }, []);

  // const lost =
  //   (roundResult && roundResult.outcome == "matchLost") ||
  //   roundResult?.outcome == "roundLost";
  const won =
    (roundResult && roundResult.outcome == "matchWon") ||
    roundResult?.outcome == "roundWon";

  return (
    <main className="pointer-events-none fixed inset-x-0 top-5 z-50 flex justify-center px-4">
      <div className="flex flex-col items-center">
        <section
          aria-label="Duel timer"
          className="flex min-w-48 items-center justify-center gap-4 border border-[#c4b596] bg-[#f7f1e3]/95 px-6 py-3 text-[#24201d] shadow-lg"
        >
          <div aria-hidden="true" className="h-9 w-px bg-[#842326]" />
          <div className="flex flex-col items-center">
            <div className="text-[10px] font-bold uppercase tracking-[0.2em] text-[#746751]">
              Round timer
            </div>
            <time
              className="font-display text-3xl leading-none tabular-nums text-[#842326]"
              dateTime="PT0S"
              role="timer"
              aria-live="off"
            >
              {isTie && <>TIE!</>}
              {!isTie && timer === 0 && <>TIME!</>}
              {timer > 0 && <>{timer}</>}
            </time>
          </div>
          <div aria-hidden="true" className="h-9 w-px bg-[#842326]" />
        </section>

        <div
          className={`overflow-hidden transition-[max-height,margin] duration-500 ease-out ${
            isResultVisible ? "mt-2 max-h-12" : "mt-0 max-h-0"
          }`}
        >
          <div
            aria-live="polite"
            className={`border px-4 py-2 text-xs font-bold uppercase tracking-[0.14em] shadow-md transition-transform duration-500 ease-out ${
              won
                ? "border-[#8a8056] bg-[#f7f1e3]/95 text-[#625b35]"
                : "border-[#842326]/50 bg-[#f7f1e3]/95 text-[#842326]"
            } ${isResultVisible ? "translate-y-0" : "-translate-y-full"}`}
          >
            {roundResult?.outcome === "matchLost" && "You lost this duel."}
            {roundResult?.outcome === "matchDraw" && "The duel ended in a draw."}
            {roundResult?.outcome === "roundLost" && "You lost this round."}
            {roundResult?.outcome === "matchWon" && "You won this duel."}
            {roundResult?.outcome === "roundWon" && "You won this round."}
          </div>
        </div>
      </div>
    </main>
  );
};

export default DuelTimerPage;
