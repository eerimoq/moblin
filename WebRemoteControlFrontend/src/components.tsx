import type { Accessor, JSX, ParentProps } from "solid-js";
import { For, onCleanup, onMount, Show, splitProps } from "solid-js";
import { Portal } from "solid-js/web";
import { twMerge } from "tailwind-merge";
import { connectionStatus } from "./utils.ts";

const iconPaths = {
  monitor: ["M4 5h16v11H4zM9 20h6M12 16v4"],
  sun: [
    "M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4",
  ],
  moon: ["M20 14.5A8 8 0 0 1 9.5 4 8 8 0 1 0 20 14.5z"],
  mic: ["M9 3h6v11H9z", "M5 11a7 7 0 0 0 14 0M12 18v3"],
  micOff: ["M3 3l18 18M9 9v5h5M15 9V3H9", "M5 11a7 7 0 0 0 11 5.7M19 11a7 7 0 0 1-.6 2.8M12 18v3"],
  eye: ["M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7z", "M12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z"],
  eyeOff: [
    "M3 3l18 18M10.6 5.1A10 10 0 0 1 22 12a10 10 0 0 1-2.4 3.4M6.5 6.5A10 10 0 0 0 2 12s3.5 7 10 7a9 9 0 0 0 5.5-1.6",
  ],
  reload: ["M21 12a9 9 0 1 1-3-6.7", "M21 3v6h-6"],
  copy: ["M9 9h12v12H9z", "M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"],
  trash: ["M3 6h18", "M8 6V4h8v2", "M19 6l-1 14H6L5 6"],
  up: ["M5 15l7-7 7 7"],
  down: ["M5 9l7 7 7-7"],
  left: ["M15 5l-7 7 7 7"],
  right: ["M9 5l7 7-7 7"],
  check: ["M5 12.5l4.5 4.5L19 7.5"],
  wifiOff: [
    "M2 2l20 20",
    "M8.5 16.5a5 5 0 0 1 7 0",
    "M5 12.9a10 10 0 0 1 5.2-2.8",
    "M19 12.9a10 10 0 0 0-2.2-1.6",
    "M2 8.8a15 15 0 0 1 4.2-2.6",
    "M22 8.8a15 15 0 0 0-11.3-3.7",
    "M12 20h.01",
  ],
  userPlus: ["M15 19a6 6 0 0 0-12 0", "M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8z", "M19 8v6M16 11h6"],
  video: ["M2 6h14v12H2z", "M16 10l6-3v10l-6-3"],
  search: ["M11 4a7 7 0 1 0 0 14 7 7 0 0 0 0-14z", "M20 20l-4-4"],
  plus: ["M12 5v14M5 12h14"],
};

export type IconName = keyof typeof iconPaths;

export function Icon(props: { name: IconName; size?: number; stroke?: number; class?: string }) {
  return (
    <svg
      width={props.size ?? 15}
      height={props.size ?? 15}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width={props.stroke ?? 2}
      stroke-linecap="round"
      stroke-linejoin="round"
      class={twMerge("shrink-0", props.class)}
    >
      <For each={iconPaths[props.name]}>{(path) => <path d={path} />}</For>
    </svg>
  );
}

export function Chevron(props: { class?: string }) {
  return (
    <svg
      width="9"
      height="6"
      viewBox="0 0 10 6"
      fill="none"
      stroke="currentColor"
      stroke-width="1.5"
      stroke-linecap="round"
      stroke-linejoin="round"
      class={twMerge("shrink-0 text-muted", props.class)}
    >
      <path d="M1 1l4 4 4-4" />
    </svg>
  );
}

export function Card(props: ParentProps<{ class?: string }>) {
  return (
    <section
      class={twMerge(
        "flex min-w-0 flex-col rounded-2xl border border-card-stroke bg-card p-4 desktop:p-[22px]",
        props.class,
      )}
    >
      {props.children}
    </section>
  );
}

export function Label(props: ParentProps<{ class?: string }>) {
  return (
    <div
      class={twMerge(
        "text-[11px] font-semibold tracking-[0.08em] text-muted uppercase",
        props.class,
      )}
    >
      {props.children}
    </div>
  );
}

export function StatusDot(props: ParentProps<{ class?: string }>) {
  return (
    <div class={twMerge("flex items-center gap-1.5 text-[11px] tracking-[0.04em]", props.class)}>
      <div class="size-1.5 rounded-full bg-current" />
      {props.children}
    </div>
  );
}

const buttonVariants = {
  control: "border border-control-stroke bg-control text-fg",
  raised: "border border-raised-stroke bg-raised text-fg",
  small:
    "h-7 gap-1.5 rounded-md border border-button-stroke bg-button px-2.5 text-[12px] text-fg shadow-[inset_0_1px_0_var(--highlight)]",
  dashed: "border border-dashed border-dash bg-transparent text-fg",
  danger: "bg-danger font-semibold text-white",
  dangerSoft: "border border-danger-stroke bg-danger-soft text-danger-fg",
  accent: "bg-accent font-semibold text-white",
  selected: "border border-accent bg-accent-surface text-accent-fg",
};

export type ButtonVariant = keyof typeof buttonVariants;

interface ButtonProps extends JSX.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
}

export function Button(props: ButtonProps) {
  const [local, rest] = splitProps(props, ["variant", "class", "type"]);
  return (
    <button
      type={local.type ?? "button"}
      class={twMerge(
        "flex items-center justify-center gap-2 rounded-[9px] whitespace-nowrap transition-[filter,opacity] select-none active:brightness-125 disabled:cursor-not-allowed disabled:opacity-40 disabled:active:brightness-100",
        buttonVariants[local.variant ?? "control"],
        local.class,
      )}
      {...rest}
    />
  );
}

interface HoldButtonProps {
  class?: string;
  disabled?: boolean;
  onStart: () => void;
  onStop: () => void;
  children?: JSX.Element;
}

export function HoldButton(props: HoldButtonProps) {
  let holding = false;

  function start(event: PointerEvent): void {
    event.preventDefault();
    if (holding || props.disabled) return;
    holding = true;
    const target = event.currentTarget as HTMLElement;
    try {
      target.setPointerCapture(event.pointerId);
    } catch {
      // Ignore, the button still works without pointer capture.
    }
    props.onStart();
  }

  function stop(): void {
    if (!holding) return;
    holding = false;
    props.onStop();
  }

  onMount(() => {
    window.addEventListener("blur", stop);
    onCleanup(() => {
      window.removeEventListener("blur", stop);
      stop();
    });
  });

  return (
    <button
      type="button"
      disabled={props.disabled}
      class={twMerge(
        "flex touch-none items-center justify-center rounded-lg border border-control-stroke bg-control text-fg select-none active:bg-selected disabled:cursor-not-allowed disabled:opacity-40",
        props.class,
      )}
      onPointerDown={start}
      onPointerUp={stop}
      onPointerCancel={stop}
      onLostPointerCapture={stop}
    >
      {props.children}
    </button>
  );
}

interface SwitchProps {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label?: string;
  disabled?: boolean;
}

export function Switch(props: SwitchProps) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={props.checked}
      aria-label={props.label}
      disabled={props.disabled}
      class={twMerge(
        "flex h-[18px] w-8 shrink-0 items-center rounded-full p-0.5 transition-colors disabled:opacity-40",
        props.checked ? "justify-end bg-accent" : "justify-start bg-button-stroke",
      )}
      onClick={() => props.onChange(!props.checked)}
    >
      <div class="size-3.5 rounded-full bg-knob shadow-[0_1px_2px_rgb(0_0_0/0.4)]" />
    </button>
  );
}

export function Checkbox(props: { checked: boolean; onChange: (checked: boolean) => void }) {
  return (
    <button
      type="button"
      role="checkbox"
      aria-checked={props.checked}
      class={twMerge(
        "flex size-[18px] shrink-0 items-center justify-center rounded-[5px]",
        props.checked ? "bg-accent text-white" : "border-[1.5px] border-control-stroke bg-control",
      )}
      onClick={() => props.onChange(!props.checked)}
    >
      <Show when={props.checked}>
        <Icon name="check" size={12} stroke={3.2} />
      </Show>
    </button>
  );
}

interface SliderProps {
  min: number;
  max: number;
  step?: number;
  value: number;
  onInput: (value: number) => void;
  onChange: (value: number) => void;
  off?: boolean;
  disabled?: boolean;
  class?: string;
}

export function Slider(props: SliderProps) {
  const percent = () =>
    Math.min(100, Math.max(0, ((props.value - props.min) / (props.max - props.min)) * 100));
  return (
    <div
      class={twMerge(
        "relative flex h-4 min-w-0 flex-1 items-center",
        props.disabled && "opacity-40",
        props.class,
      )}
    >
      <div class="relative h-1 w-full rounded-sm bg-selected">
        <Show when={!props.off}>
          <div class="h-1 rounded-sm bg-accent" style={{ width: `${percent()}%` }} />
        </Show>
        <div
          class={twMerge(
            "absolute top-[-6px] size-4 -translate-x-1/2 rounded-full border-[3px]",
            props.off ? "border-selected bg-faint" : "border-accent bg-knob",
          )}
          style={{ left: `${percent()}%` }}
        />
      </div>
      <input
        type="range"
        class="absolute inset-x-0 -inset-y-2 w-full cursor-pointer opacity-0"
        min={props.min}
        max={props.max}
        step={props.step ?? 1}
        value={props.value}
        disabled={props.disabled}
        onInput={(event) => props.onInput(parseFloat(event.currentTarget.value))}
        onChange={(event) => props.onChange(parseFloat(event.currentTarget.value))}
      />
    </div>
  );
}

export interface SegmentOption<T> {
  value: T;
  label: JSX.Element;
}

interface SegmentedProps<T> {
  options: SegmentOption<T>[];
  value: T | undefined;
  onChange: (value: T) => void;
  class?: string;
  itemClass?: string;
  disabled?: boolean;
}

export function Segmented<T>(props: SegmentedProps<T>) {
  return (
    <div
      class={twMerge(
        "flex gap-0.5 rounded-[9px] border border-control-stroke bg-control p-[3px]",
        props.disabled && "opacity-40",
        props.class,
      )}
    >
      <For each={props.options}>
        {(option) => (
          <button
            type="button"
            disabled={props.disabled}
            class={twMerge(
              "flex h-8 min-w-0 flex-1 basis-0 items-center justify-center rounded-[7px] text-[12px] whitespace-nowrap",
              option.value === props.value
                ? "bg-accent font-semibold text-white"
                : "text-fg-3 active:bg-selected",
              props.itemClass,
            )}
            onClick={() => props.onChange(option.value)}
          >
            {option.label}
          </button>
        )}
      </For>
    </div>
  );
}

export interface SelectOption {
  value: string;
  label: string;
}

interface SelectProps {
  options: SelectOption[];
  value: string;
  onChange: (value: string) => void;
  prefix?: string;
  placeholder?: string;
  class?: string;
  disabled?: boolean;
}

export function Select(props: SelectProps) {
  const label = () =>
    props.options.find((option) => option.value === props.value)?.label ?? props.placeholder ?? "";
  return (
    <div
      class={twMerge(
        "relative flex h-10 min-w-0 items-center justify-between gap-2 rounded-[9px] border border-control-stroke bg-control px-3 text-fg",
        props.disabled && "opacity-40",
        props.class,
      )}
    >
      <div class="flex min-w-0 items-center gap-2.5">
        <Show when={props.prefix}>
          <span class="shrink-0 text-[12px] text-muted">{props.prefix}</span>
        </Show>
        <span class="truncate">{label()}</span>
      </div>
      <Chevron />
      <select
        class="absolute inset-0 cursor-pointer appearance-none opacity-0"
        value={props.value}
        disabled={props.disabled}
        onChange={(event) => props.onChange(event.currentTarget.value)}
      >
        <Show when={props.placeholder !== undefined}>
          <option value="" disabled>
            {props.placeholder}
          </option>
        </Show>
        <For each={props.options}>
          {(option) => (
            <option value={option.value} selected={option.value === props.value}>
              {option.label}
            </option>
          )}
        </For>
      </select>
    </div>
  );
}

interface TextFieldProps {
  value: string;
  onCommit: (value: string) => void;
  placeholder?: string;
  class?: string;
  inputMode?: "text" | "numeric" | "decimal";
  disabled?: boolean;
}

export function TextField(props: TextFieldProps) {
  return (
    <input
      type="text"
      inputMode={props.inputMode}
      class={twMerge(
        "h-10 min-w-0 rounded-[9px] border border-control-stroke bg-control px-3 text-fg outline-none focus:border-accent disabled:opacity-40",
        props.class,
      )}
      value={props.value}
      placeholder={props.placeholder}
      disabled={props.disabled}
      onKeyDown={(event) => {
        if (event.key === "Enter") event.currentTarget.blur();
      }}
      onChange={(event) => props.onCommit(event.currentTarget.value)}
    />
  );
}

export function ColorButton(props: {
  value: string;
  onChange: (value: string) => void;
  label?: string;
  class?: string;
}) {
  return (
    <label
      class={twMerge(
        "relative flex h-10 shrink-0 cursor-pointer items-center gap-2 rounded-[9px] border border-control-stroke bg-control",
        props.label ? "pr-3 pl-2" : "w-10 justify-center",
        props.class,
      )}
    >
      <div
        class="size-[22px] rounded-md border border-button-stroke"
        style={{ "background-color": props.value }}
      />
      <Show when={props.label}>
        <span class="text-[12px] text-fg-3">{props.label}</span>
      </Show>
      <input
        type="color"
        class="absolute inset-0 size-full cursor-pointer opacity-0"
        value={props.value}
        onInput={(event) => props.onChange(event.currentTarget.value)}
      />
    </label>
  );
}

export interface DialogConfig {
  title: string;
  message: string;
  cancelLabel?: string;
  confirmLabel: string;
  confirmVariant?: ButtonVariant;
  onConfirm: () => void;
}

export function Dialog(props: { config: Accessor<DialogConfig | null>; onClose: () => void }) {
  function onKeyDown(event: KeyboardEvent): void {
    if (event.key === "Escape") props.onClose();
  }
  onMount(() => {
    window.addEventListener("keydown", onKeyDown);
    onCleanup(() => window.removeEventListener("keydown", onKeyDown));
  });
  return (
    <Show when={props.config()}>
      {(config) => (
        <Portal>
          <div
            class="fixed inset-0 z-50 flex items-center justify-center bg-overlay p-4"
            onClick={() => props.onClose()}
          >
            <div
              class="flex w-full max-w-[440px] flex-col gap-5 rounded-2xl border border-card-stroke bg-card p-5 shadow-[0_24px_64px_rgb(0_0_0/0.5)] tablet:p-6"
              onClick={(event) => event.stopPropagation()}
            >
              <div class="flex flex-col gap-2.5">
                <div class="text-base font-semibold">{config().title}</div>
                <div class="text-[12px] leading-[19px] text-fg-3">{config().message}</div>
              </div>
              <div class="flex justify-end gap-2 max-tablet:*:h-11 max-tablet:*:flex-1">
                <Button class="h-9 rounded-lg px-4" onClick={() => props.onClose()}>
                  {config().cancelLabel ?? "Cancel"}
                </Button>
                <Button
                  variant={config().confirmVariant ?? "danger"}
                  class="h-9 rounded-lg px-4"
                  onClick={() => {
                    const { onConfirm } = config();
                    props.onClose();
                    onConfirm();
                  }}
                >
                  {config().confirmLabel}
                </Button>
              </div>
            </div>
          </div>
        </Portal>
      )}
    </Show>
  );
}

export function EmptyState(props: {
  icon: IconName;
  title: string;
  message: string;
  class?: string;
  children?: JSX.Element;
}) {
  return (
    <div
      class={twMerge(
        "flex flex-col items-center justify-center gap-3.5 rounded-xl border border-dashed border-card-stroke bg-well-soft px-6 py-16 text-center",
        props.class,
      )}
    >
      <div class="flex size-12 items-center justify-center rounded-[14px] bg-raised text-muted">
        <Icon name={props.icon} size={22} stroke={1.8} />
      </div>
      <div class="text-[15px] font-semibold">{props.title}</div>
      <div class="max-w-[440px] text-[12px] leading-[18px] text-muted">{props.message}</div>
      {props.children}
    </div>
  );
}

interface ConnectingOverlayProps {
  status: Accessor<string>;
}

export function ConnectingOverlay({ status }: ConnectingOverlayProps) {
  return (
    <Show when={status() !== connectionStatus.connected}>
      <div class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm">
        <div class="relative mx-4 w-full max-w-sm rounded-2xl border border-zinc-600 bg-zinc-800 shadow-2xl ring-1 shadow-black/60 ring-white/10">
          <div class="flex flex-col items-center gap-4 px-6 py-8">
            <div class="h-10 w-10 animate-spin rounded-full border-4 border-zinc-600 border-t-indigo-400" />
            <p class="text-base leading-relaxed text-zinc-100">Connecting to server...</p>
          </div>
        </div>
      </div>
    </Show>
  );
}
