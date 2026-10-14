import { cn } from "../../../../utils/cn";

type ButtonProps = {
  type?: "button" | "submit" | "reset";
  onClick?: () => void;
  disabled?: boolean;
  children: React.ReactNode;
  variant?: "normal" | "secondary";
};

const Button = ({
  type = "button",
  variant = "normal",
  onClick,
  disabled,
  children,
}: ButtonProps) => {
  return (
    <button
      type={type}
      onClick={onClick}
      disabled={disabled}
      className={cn(
        "mt-1 inline-flex min-h-12 items-center justify-center gap-2 rounded-full bg-[#842326] px-7 font-medium text-[#fffaf0] transition-colors hover:bg-[#6f1c1f] focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#842326] active:bg-[#5c171a]",
        disabled && "bg-[#693133]",
        variant === "secondary" &&
          "hover:border-[#c99a61] hover:bg-[#f2e4c9] hover:text-[#6d431e] border-[#c99a61] bg-[#f7f1e3] text-[#625b50",
      )}
    >
      {children}
    </button>
  );
};

export default Button;
