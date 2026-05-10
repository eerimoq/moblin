import type { Accessor, JSX, ParentProps } from "solid-js";
import { For, Show } from "solid-js";
import { twMerge } from "tailwind-merge";

interface ButtonProps {
  class?: string;
  type?: "button" | "submit" | "reset";
  onClick?: (event: MouseEvent) => void;
  children?: JSX.Element;
}

export function Button({ class: extraClass, type = "button", onClick, children }: ButtonProps) {
  return (
    <button
      type={type}
      class={twMerge(
        "cursor-pointer rounded border border-zinc-700 px-3 py-1 text-sm transition-colors hover:bg-zinc-800",
        extraClass,
      )}
      onClick={onClick}
    >
      {children}
    </button>
  );
}

interface ConfirmDialogProps {
  open: Accessor<boolean>;
  message: Accessor<string>;
  onOk: () => void;
  onCancel: () => void;
  okTextClass: string;
  okLabel?: string;
}

export function ConfirmDialog({
  open,
  message,
  onOk,
  onCancel,
  okTextClass,
  okLabel = "OK",
}: ConfirmDialogProps) {
  return (
    <Show when={open()}>
      <div
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/70 backdrop-blur-sm"
        onClick={onCancel}
      >
        <div
          class="relative w-full max-w-sm mx-4 rounded-2xl border border-zinc-600 bg-zinc-800 shadow-2xl shadow-black/60 ring-1 ring-white/10"
          onClick={(e) => e.stopPropagation()}
        >
          <div class="px-6 pt-6 pb-4">
            <p class="text-base text-zinc-100 leading-relaxed">{message()}</p>
          </div>
          <div class="flex items-center justify-end gap-2 border-t border-zinc-700 px-6 py-4">
            <Button
              class={`py-2 px-4 rounded-lg font-medium hover:bg-zinc-600 ${okTextClass}`}
              onClick={onOk}
            >
              {okLabel}
            </Button>
            <Button
              class="py-2 px-4 rounded-lg font-medium text-zinc-300 border border-zinc-600 hover:bg-zinc-700"
              onClick={onCancel}
            >
              Cancel
            </Button>
          </div>
        </div>
      </div>
    </Show>
  );
}

export function Section(props: ParentProps<{ title: string }>) {
  return (
    <div class="bg-zinc-900 border border-zinc-700 rounded-lg p-2">
      <h2 class="text-xl font-semibold mb-3">{props.title}</h2>
      {props.children}
    </div>
  );
}

export function GitHubLink() {
  return (
    <a
      href="https://github.com/eerimoq/moblin"
      target="_blank"
      class="text-indigo-400 hover:text-indigo-300 text-sm"
    >
      Github
    </a>
  );
}

export function RemoteControlLink() {
  return (
    <a href="./" class="text-indigo-400 hover:text-indigo-300 text-sm">
      Remote Control
    </a>
  );
}

export function BasicLinks() {
  return (
    <div class="pb-1 text-center space-x-4">
      <RemoteControlLink />
      <GitHubLink />
    </div>
  );
}

export interface NamedItem {
  id: string;
  name: string;
}

export interface PickerProps {
  name: string;
  options: Accessor<NamedItem[]>;
  value: Accessor<string>;
  onChange: (value: string) => void;
}

export function Picker({ name, options, value, onChange }: PickerProps) {
  return (
    <div class="flex items-center space-x-4">
      <label class="text-sm text-zinc-200 w-24 shrink-0">{name}</label>
      <Show when={options().length > 0}>
        <select
          class="bg-zinc-800 border border-zinc-600 rounded px-2 py-1 text-sm text-zinc-200 flex-1"
          value={value()}
          onChange={(event) => onChange(event.target.value)}
        >
          <For each={options()}>
            {(option) => (
              <option value={option.id} selected={option.id === value()}>
                {option.name}
              </option>
            )}
          </For>
        </select>
      </Show>
    </div>
  );
}

export interface ToggleProps {
  id: string;
  checked: boolean;
  onChange: (event: Event & { target: HTMLInputElement }) => void;
  label: string;
}

export function Toggle(props: ToggleProps) {
  return (
    <label class="flex items-center cursor-pointer">
      <div class="relative flex items-center">
        <input
          id={props.id}
          type="checkbox"
          class="peer appearance-none w-11 h-5 bg-slate-400 rounded-full checked:bg-indigo-800 cursor-pointer transition-colors duration-300"
          checked={props.checked}
          role="switch"
          onChange={props.onChange}
        />
        <label
          for={props.id}
          class="absolute top-0 left-0 w-5 h-5 bg-white rounded-full border border-indigo-300 shadow-sm transition-transform duration-300 peer-checked:translate-x-6 peer-checked:border-slate-800 cursor-pointer"
        />
        <span class="ml-3 text-sm text-zinc-200">{props.label}</span>
      </div>
    </label>
  );
}
