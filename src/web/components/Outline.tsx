export type OutlineItem = {
  id: string;
  text: string;
  depth: number;
};

export function Outline({ items }: { items: OutlineItem[] }) {
  return (
    <aside className="outline" aria-label="On this page">
      {items.map((item) => (
        <a key={item.id} className={`outline-item depth-${item.depth}`} href={`#${item.id}`}>
          {item.text}
        </a>
      ))}
    </aside>
  );
}
