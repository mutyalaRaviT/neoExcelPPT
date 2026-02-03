<script>
  import { onMount } from 'svelte';

  // Props from LiveView
  export let dsl = '';
  export let live;  // LiveSvelte pushEvent
  export let readonly = false;

  let textarea;
  let localDsl = dsl;
  let isDirty = false;
  let error = null;
  let isValid = true;

  // Sync with prop changes
  $: if (dsl !== localDsl && !isDirty) {
    localDsl = dsl;
  }

  // Basic S-expression validation
  function validateSExpr(code) {
    let depth = 0;
    for (const char of code) {
      if (char === '(') depth++;
      if (char === ')') depth--;
      if (depth < 0) return { valid: false, error: 'Unexpected closing parenthesis' };
    }
    if (depth !== 0) return { valid: false, error: `Unclosed parentheses (${depth} open)` };
    return { valid: true, error: null };
  }

  // Handle input changes
  function handleInput(e) {
    localDsl = e.target.value;
    isDirty = true;

    // Validate
    const result = validateSExpr(localDsl);
    isValid = result.valid;
    error = result.error;
  }

  // Send changes to LiveView
  function handleBlur() {
    if (isDirty && isValid && live) {
      live.pushEvent('dsl_changed', { dsl: localDsl });
      isDirty = false;
    }
  }

  // Keyboard shortcuts
  function handleKeydown(e) {
    // Ctrl/Cmd + Enter to apply
    if ((e.ctrlKey || e.metaKey) && e.key === 'Enter') {
      if (isValid && live) {
        live.pushEvent('dsl_apply', { dsl: localDsl });
        isDirty = false;
      }
    }

    // Tab inserts spaces
    if (e.key === 'Tab') {
      e.preventDefault();
      const start = textarea.selectionStart;
      const end = textarea.selectionEnd;
      localDsl = localDsl.substring(0, start) + '  ' + localDsl.substring(end);
      setTimeout(() => {
        textarea.selectionStart = textarea.selectionEnd = start + 2;
      }, 0);
    }
  }

  // Format DSL (basic indentation)
  function formatDsl() {
    let formatted = '';
    let indent = 0;
    let inString = false;

    for (let i = 0; i < localDsl.length; i++) {
      const char = localDsl[i];
      const prevChar = i > 0 ? localDsl[i - 1] : '';

      if (char === '"' && prevChar !== '\\') {
        inString = !inString;
        formatted += char;
        continue;
      }

      if (inString) {
        formatted += char;
        continue;
      }

      if (char === '(') {
        if (formatted.length > 0 && !formatted.endsWith('\n') && !formatted.endsWith('(')) {
          formatted += '\n' + '  '.repeat(indent);
        }
        formatted += char;
        indent++;
      } else if (char === ')') {
        indent = Math.max(0, indent - 1);
        formatted += char;
      } else if (char === '\n') {
        formatted += '\n' + '  '.repeat(indent);
      } else if (char === ' ' && (prevChar === '(' || prevChar === ')')) {
        // Skip extra spaces after parens
        continue;
      } else {
        formatted += char;
      }
    }

    localDsl = formatted.trim();
    isDirty = true;
  }

  onMount(() => {
    localDsl = dsl;
  });
</script>

<div class="dsl-editor">
  <div class="editor-header">
    <h3>S-Expression DSL</h3>
    <div class="editor-actions">
      <button class="btn-format" on:click={formatDsl} title="Format (indent)">
        Format
      </button>
      {#if isDirty}
        <span class="dirty-indicator">•</span>
      {/if}
      {#if !isValid}
        <span class="error-indicator" title={error}>⚠ Invalid</span>
      {/if}
    </div>
  </div>

  <div class="editor-body">
    <textarea
      bind:this={textarea}
      bind:value={localDsl}
      on:input={handleInput}
      on:blur={handleBlur}
      on:keydown={handleKeydown}
      {readonly}
      class:invalid={!isValid}
      placeholder="(define-skill :project-scope
  (inputs :file-counts)
  (outputs :total-files :breakdown)
  (compute
    (let [files (get input :file-counts)]
      (emit :total-files (sum files))
      (emit :breakdown (categorize files)))))"
      spellcheck="false"
    ></textarea>

    {#if error}
      <div class="error-message">{error}</div>
    {/if}
  </div>

  <div class="editor-footer">
    <span class="hint">Ctrl+Enter to apply changes</span>
    <span class="syntax-help">
      <a href="#" on:click|preventDefault={() => live?.pushEvent('show_dsl_help', {})}>
        DSL Reference
      </a>
    </span>
  </div>
</div>

<style>
  .dsl-editor {
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    background: #1e293b;
    overflow: hidden;
    display: flex;
    flex-direction: column;
    height: 100%;
  }

  .editor-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 8px 12px;
    background: #0f172a;
    border-bottom: 1px solid #334155;
  }

  .editor-header h3 {
    margin: 0;
    font-size: 13px;
    font-weight: 600;
    color: #f1f5f9;
  }

  .editor-actions {
    display: flex;
    align-items: center;
    gap: 8px;
  }

  .btn-format {
    padding: 4px 8px;
    font-size: 11px;
    background: #334155;
    color: #e2e8f0;
    border: none;
    border-radius: 4px;
    cursor: pointer;
    transition: background 0.2s;
  }

  .btn-format:hover {
    background: #475569;
  }

  .dirty-indicator {
    color: #fbbf24;
    font-size: 20px;
    line-height: 1;
  }

  .error-indicator {
    color: #ef4444;
    font-size: 11px;
    font-weight: 500;
  }

  .editor-body {
    flex: 1;
    position: relative;
  }

  textarea {
    width: 100%;
    height: 100%;
    min-height: 400px;
    padding: 12px;
    border: none;
    background: #1e293b;
    color: #e2e8f0;
    font-family: 'JetBrains Mono', 'Fira Code', 'SF Mono', Consolas, monospace;
    font-size: 13px;
    line-height: 1.6;
    resize: none;
    outline: none;
  }

  textarea::placeholder {
    color: #475569;
  }

  textarea.invalid {
    border-left: 3px solid #ef4444;
  }

  .error-message {
    position: absolute;
    bottom: 8px;
    left: 8px;
    right: 8px;
    padding: 6px 10px;
    background: #450a0a;
    color: #fca5a5;
    border-radius: 4px;
    font-size: 11px;
  }

  .editor-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 6px 12px;
    background: #0f172a;
    border-top: 1px solid #334155;
  }

  .hint {
    font-size: 10px;
    color: #64748b;
  }

  .syntax-help a {
    font-size: 10px;
    color: #3b82f6;
    text-decoration: none;
  }

  .syntax-help a:hover {
    text-decoration: underline;
  }
</style>
