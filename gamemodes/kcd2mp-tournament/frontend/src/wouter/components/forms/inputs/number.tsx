import { forwardRef } from "react";

type NumberProps = {
  label: string;
  disabled?: boolean;
  onRightArrowClick?: () => void;
  onLeftArrowClick?: () => void;
};

const Number = forwardRef<HTMLInputElement, NumberProps>(
  ({ label, disabled, onRightArrowClick, onLeftArrowClick, ...props }, ref) => (
    <div className="flex flex-col gap-2">
      <label className="text-sm font-medium">{label}</label>
      <div className="flex items-center gap-2">
        <button
          type="button"
          onClick={onLeftArrowClick}
          disabled={disabled}
          aria-label={`Decrease ${label.toLowerCase()}`}
          className="flex size-11 shrink-0 items-center justify-center border border-[#c4b596] bg-[#f7f1e3] text-lg transition-colors hover:bg-[#eee4d0] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#842326] disabled:cursor-not-allowed disabled:opacity-50"
        >
          ←
        </button>
        <input
          {...props}
          ref={ref}
          type="number"
          disabled={disabled}
          className="h-11 min-w-0 flex-1 border border-[#c4b596] bg-[#fffdf7] px-3 text-center text-lg tabular-nums outline-none focus:border-[#842326] focus:ring-2 focus:ring-[#842326]/20 disabled:cursor-not-allowed disabled:opacity-50"
        />
        <button
          type="button"
          onClick={onRightArrowClick}
          disabled={disabled}
          aria-label={`Increase ${label.toLowerCase()}`}
          className="flex size-11 shrink-0 items-center justify-center border border-[#c4b596] bg-[#f7f1e3] text-lg transition-colors hover:bg-[#eee4d0] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#842326] disabled:cursor-not-allowed disabled:opacity-50"
        >
          →
        </button>
      </div>
    </div>
  ),
);

export default Number;
