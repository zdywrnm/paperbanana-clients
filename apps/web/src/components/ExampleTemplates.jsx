import { BookOpen } from 'lucide-react';

export default function ExampleTemplates({ examples, onApply }) {
  return (
    <div className="example-panel">
      <div className="example-panel-head">
        <BookOpen size={16} />
        <span>快速上手案例</span>
      </div>
      <div className="example-grid">
        {examples.map((example) => (
          <button className="example-card" type="button" key={example.id} onClick={() => onApply(example)}>
            <span>{example.label}</span>
            <strong>{example.title}</strong>
            <small>{example.caption}</small>
            <em>{example.hint}</em>
          </button>
        ))}
      </div>
    </div>
  );
}
