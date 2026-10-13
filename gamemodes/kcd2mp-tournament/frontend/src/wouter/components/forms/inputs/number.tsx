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
      <p>{label}</p>
      <div className="flex items-center gap-2">
        <button type="button" onClick={onLeftArrowClick} disabled={disabled}>
          ←
        </button>
        <input
          {...props}
          ref={ref}
          type="number"
          disabled={disabled}
          className="appearance-none [&::-webkit-inner-spin-button]:appearance-none [&::-webkit-outer-spin-button]:appearance-none"
        />
        <button type="button" onClick={onRightArrowClick} disabled={disabled}>
          →
        </button>
      </div>
    </div>
  ),
);

export default Number;
