import { cn } from "../../../utils/cn";

type DialogBodyProps = {
  children: React.ReactNode;
  title: string;
  subtitle?: string;
};

const DialogBody = ({ children, title, subtitle }: DialogBodyProps) => {
  return (
    <div className="w-full max-w-md border border-[#c4b596] bg-[#fbf7ed] p-6 shadow-[0_8px_24px_rgba(36,32,29,0.06)] sm:p-8">
      <div className={cn(subtitle && "mb-7 border-b border-[#c4b596] pb-5")}>
        <p className="mb-2 text-xs font-bold uppercase tracking-[0.18em] text-[#842326]">
          {title}
        </p>
        {subtitle && (
          <h1 className="font-display text-3xl text-[#121010] sm:text-4xl">
            {subtitle}
          </h1>
        )}
      </div>
      {children}
    </div>
  );
};

export default DialogBody;
