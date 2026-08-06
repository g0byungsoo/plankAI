import { Fragment, useEffect, type ReactNode } from "react";

export function Token({ kind, children }: { kind: "active" | "review" | "off" | "danger"; children: ReactNode }) {
  return (
    <span className={`token ${kind}`}>
      <span className="glyph" aria-hidden="true" />
      {children}
    </span>
  );
}

export function Spinner() {
  return <span className="spinner" role="status" aria-label="loading" />;
}

export function Banner({ kind, children }: { kind: "err" | "info"; children: ReactNode }) {
  return <div className={`banner ${kind}`} role={kind === "err" ? "alert" : undefined}>{children}</div>;
}

export function Empty({ big, children }: { big: string; children?: ReactNode }) {
  return (
    <div className="empty">
      <div className="big">{big}</div>
      {children}
    </div>
  );
}

export function Sheet({ title, sub, onClose, children }: { title: string; sub?: string; onClose: () => void; children: ReactNode }) {
  useEffect(() => {
    const onKey = (e: KeyboardEvent) => { if (e.key === "Escape") onClose(); };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [onClose]);
  return (
    <div className="scrim" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose(); }}>
      <div className="sheet" role="dialog" aria-modal="true" aria-label={title}>
        <h2>{title}</h2>
        {sub && <div className="sheet-sub">{sub}</div>}
        {children}
      </div>
    </div>
  );
}

export function DL({ items }: { items: [string, ReactNode][] }) {
  return (
    <dl className="dl">
      {items.map(([k, v], i) => (
        <Fragment key={i}>
          <dt>{k}</dt>
          <dd className={typeof v === "string" && v.length > 24 ? "" : "strong"}>{v}</dd>
        </Fragment>
      ))}
    </dl>
  );
}
