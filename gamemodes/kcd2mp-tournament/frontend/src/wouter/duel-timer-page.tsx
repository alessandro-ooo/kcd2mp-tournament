import { useRef, useState } from "react";

const DuelTimerPage = () => {
  type RType = { round: number; outcome: string };
  const [roundResult, setRoundResult] = useState<RType | undefined>();
  const [displayedResult, setDisplayedResult] = useState<RType | undefined>();
  const resultTimeout = useRef<number | undefined>(undefined);

  const showRoundResult = (result: RType) => {
    window.clearTimeout(resultTimeout.current);
    setRoundResult(result);
    setDisplayedResult(result);
    resultTimeout.current = window.setTimeout(() => {
      setRoundResult(undefined);
      resultTimeout.current = undefined;
    }, 4000);
  };

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
              00:00
            </time>
          </div>
          <div aria-hidden="true" className="h-9 w-px bg-[#842326]" />
        </section>
        <div
          className={`overflow-hidden transition-[max-height,margin] duration-300 ease-out ${
            roundResult ? "mt-2 max-h-12" : "mt-0 max-h-0"
          }`}
          onTransitionEnd={(event) => {
            if (
              event.target === event.currentTarget &&
              event.propertyName === "max-height" &&
              !roundResult
            ) {
              setDisplayedResult(undefined);
            }
          }}
        >
          <div
            aria-live="polite"
            className={`border px-4 py-2 text-xs font-bold uppercase tracking-[0.14em] shadow-md transition-transform duration-300 ease-out ${
              displayedResult?.outcome === "won"
                ? "border-[#8a8056] bg-[#f7f1e3]/95 text-[#625b35]"
                : "border-[#842326]/50 bg-[#f7f1e3]/95 text-[#842326]"
            } ${roundResult ? "translate-y-0" : "-translate-y-full"}`}
          >
            {displayedResult &&
              `Round ${displayedResult.round} ${displayedResult.outcome}`}
          </div>
        </div>
        <button
          type="button"
          onClick={() => showRoundResult({ outcome: "won", round: 1 })}
          className="pointer-events-auto mt-2 border border-[#c4b596] bg-[#f7f1e3]/95 px-3 py-1.5 text-[10px] font-bold uppercase tracking-[0.14em] text-[#746751] shadow-md transition-colors hover:bg-[#eee3ce] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#842326]"
        >
          Debug round result
        </button>
      </div>
    </main>
  );
};

export default DuelTimerPage;
