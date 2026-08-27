import { avatarColor } from '../util';

interface Props {
  src?: string | null;
  name: string;
  size?: number;
  /** round = circle (groups/mine), square = rounded square (default WeChat style) */
  round?: boolean;
}

export default function Avatar({ src, name, size = 44, round = false }: Props) {
  const initial = name ? name.trim().slice(0, 1).toUpperCase() : '?';
  const radius = round ? size / 2 : Math.max(6, Math.round(size * 0.18));
  const style: React.CSSProperties = {
    width: size,
    height: size,
    borderRadius: radius,
    fontSize: Math.round(size * 0.42),
    background: src ? 'transparent' : avatarColor(name),
  };
  if (src) {
    return <img className="avatar-img" src={src} alt={name} style={style} />;
  }
  return (
    <div className="avatar-img" style={style}>
      {initial}
    </div>
  );
}
