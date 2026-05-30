export default function Select({ label, value, onChange, options }) {
  const hasGroups = options.some((option) => option[2]);
  const groups = hasGroups
    ? options.reduce((acc, option) => {
        const group = option[2] || '其他';
        acc[group] = acc[group] || [];
        acc[group].push(option);
        return acc;
      }, {})
    : null;

  return (
    <label className="field compact">
      <span>{label}</span>
      <select value={value} onChange={(event) => onChange(event.target.value)}>
        {groups
          ? Object.entries(groups).map(([group, items]) => (
              <optgroup key={group} label={group}>
                {items.map(([id, text]) => <option key={id} value={id}>{text}</option>)}
              </optgroup>
            ))
          : options.map(([id, text]) => <option key={id} value={id}>{text}</option>)}
      </select>
    </label>
  );
}
