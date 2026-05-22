export function ErrorView({ title, detail }: { title: string; detail: string }) {
  return (
    <section className="error-view" role="alert">
      <h1>{title}</h1>
      <p>{detail}</p>
    </section>
  );
}
