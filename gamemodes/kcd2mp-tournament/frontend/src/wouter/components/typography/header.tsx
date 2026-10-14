type H1Props = {
  children: React.ReactNode;
};

const H1 = ({ children }: H1Props) => {
  return (
    <div className="border-b border-[#c4b596] pb-5">
      <h1 className="font-display text-3xl text-[#121010] sm:text-4xl">
        {children}
      </h1>
    </div>
  );
};

export default H1;
