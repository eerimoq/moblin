import type { Accessor } from "solid-js";
import { For, Show } from "solid-js";

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
      <dialog
        open
        class="backdrop:bg-black/60 rounded-xl p-0"
        style={{
          position: "fixed",
          top: "50%",
          left: "50%",
          transform: "translate(-50%, -50%)",
          margin: 0,
        }}
      >
        <form method="dialog" class="bg-zinc-900 text-zinc-100">
          <div class="p-2">
            <p class="text-zinc-300">{message()}</p>
          </div>
          <div class="bg-zinc-800/60 px-4 py-3 sm:px-5 flex items-center justify-end gap-2">
            <button
              type="button"
              class={`px-3 py-1.5 rounded-md border border-zinc-700 hover:bg-zinc-800 cursor-pointer ${okTextClass}`}
              onClick={onOk}
            >
              {okLabel}
            </button>
            <button
              type="button"
              class="px-3 py-1.5 rounded-md border border-zinc-700 text-zinc-300 hover:bg-zinc-800 cursor-pointer"
              onClick={onCancel}
            >
              Cancel
            </button>
          </div>
        </form>
      </dialog>
    </Show>
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
            {(option) => <option value={option.id}> {option.name} </option>}
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
