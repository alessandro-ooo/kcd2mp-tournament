import { forwardRef, type ComponentPropsWithoutRef } from "react";

type CheckboxProps = Omit<ComponentPropsWithoutRef<"input">, "type"> & {
  label: string;
};

const Checkbox = forwardRef<HTMLInputElement, CheckboxProps>(
  ({ label, className, ...props }, ref) => (
    <label className="flex cursor-pointer items-center gap-3 text-base">
      <input
        {...props}
        ref={ref}
        type="checkbox"
        className={`size-4 accent-[#842326] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#842326]${className ? ` ${className}` : ""}`}
      />
      <span>{label}</span>
    </label>
  ),
);

export default Checkbox;
