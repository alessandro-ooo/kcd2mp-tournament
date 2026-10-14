import { forwardRef, type ComponentPropsWithoutRef } from "react";
import { cn } from "../../../../utils/cn";

type SelectProps = Omit<
  ComponentPropsWithoutRef<"select">,
  "children" | "defaultValue" | "value"
> & {
  label: string;
  selected: { name: string; value: string };
  items: { name: string; value: string }[];
};

const Select = forwardRef<HTMLSelectElement, SelectProps>(
  ({ label, selected, items, className, ...props }, ref) => {
    return (
      <div className="flex flex-col gap-2">
        <p className="text-xs font-bold uppercase tracking-[0.12em] text-[#746751]">
          {label}
        </p>
        <div className="relative">
          <select
            {...props}
            ref={ref}
            defaultValue={selected.value}
            className={cn(
              "min-h-11 w-full appearance-none border border-[#c4b596] bg-[#fffdf7] px-3 pr-10 text-base text-[#24201d] transition-colors hover:border-[#a88e69] focus-visible:border-[#842326] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#842326] disabled:cursor-not-allowed disabled:bg-[#f7f1e3] disabled:text-[#746751] disabled:opacity-70",
              className,
            )}
          >
            {items.map((item) => (
              <option key={item.value} value={item.value}>
                {item.name}
              </option>
            ))}
          </select>
          <svg
            aria-hidden="true"
            viewBox="0 0 20 20"
            fill="none"
            className="pointer-events-none absolute right-3 top-1/2 size-4 -translate-y-1/2 text-[#746751]"
          >
            <path
              d="m5 7.5 5 5 5-5"
              stroke="currentColor"
              strokeWidth="1.75"
              strokeLinecap="round"
              strokeLinejoin="round"
            />
          </svg>
        </div>
      </div>
    );
  },
);

export default Select;
