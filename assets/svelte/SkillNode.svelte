<script>
  import { Handle, Position } from '@xyflow/svelte';

  export let data;

  const { label, skillId, inputs, outputs, state, live } = data;

  // Handle click to select skill
  function handleClick() {
    if (live) {
      live.pushEvent('skill_selected', { skill_id: skillId });
    }
  }

  // Format state value for display
  function formatValue(val) {
    if (typeof val === 'number') {
      return val.toLocaleString();
    }
    if (typeof val === 'object') {
      return JSON.stringify(val).slice(0, 30);
    }
    return String(val);
  }
</script>

<div class="skill-node" on:click={handleClick} on:keydown={handleClick} role="button" tabindex="0">
  <!-- Input Handles (left side) -->
  {#each inputs as input, i}
    <Handle
      type="target"
      position={Position.Left}
      id={input}
      style="top: {30 + i * 20}px; background: #10b981;"
    />
  {/each}

  <!-- Node Content -->
  <div class="skill-header">
    <span class="skill-icon">⚡</span>
    <span class="skill-label">{label}</span>
  </div>

  <div class="skill-body">
    <!-- Input channels -->
    {#if inputs.length > 0}
      <div class="channels inputs">
        <div class="channel-title">Inputs</div>
        {#each inputs as input}
          <div class="channel">
            <span class="channel-dot input">●</span>
            <span class="channel-name">{input}</span>
          </div>
        {/each}
      </div>
    {/if}

    <!-- Output channels -->
    {#if outputs.length > 0}
      <div class="channels outputs">
        <div class="channel-title">Outputs</div>
        {#each outputs as output}
          <div class="channel">
            <span class="channel-name">{output}</span>
            <span class="channel-dot output">●</span>
          </div>
        {/each}
      </div>
    {/if}

    <!-- Current state preview -->
    {#if state && Object.keys(state).length > 0}
      <div class="state-preview">
        <div class="state-title">State</div>
        {#each Object.entries(state).slice(0, 3) as [key, value]}
          <div class="state-item">
            <span class="state-key">{key}:</span>
            <span class="state-value">{formatValue(value)}</span>
          </div>
        {/each}
      </div>
    {/if}
  </div>

  <!-- Output Handles (right side) -->
  {#each outputs as output, i}
    <Handle
      type="source"
      position={Position.Right}
      id={output}
      style="top: {30 + i * 20}px; background: #3b82f6;"
    />
  {/each}
</div>

<style>
  .skill-node {
    background: white;
    border: 2px solid #3b82f6;
    border-radius: 8px;
    min-width: 180px;
    font-family: system-ui, -apple-system, sans-serif;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
    cursor: pointer;
    transition: box-shadow 0.2s, border-color 0.2s;
  }

  .skill-node:hover {
    box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
    border-color: #2563eb;
  }

  .skill-header {
    background: linear-gradient(135deg, #3b82f6, #2563eb);
    color: white;
    padding: 8px 12px;
    border-radius: 6px 6px 0 0;
    display: flex;
    align-items: center;
    gap: 6px;
    font-weight: 600;
    font-size: 13px;
  }

  .skill-icon {
    font-size: 14px;
  }

  .skill-body {
    padding: 8px 12px;
    font-size: 11px;
  }

  .channels {
    margin-bottom: 8px;
  }

  .channel-title {
    font-size: 9px;
    text-transform: uppercase;
    color: #64748b;
    font-weight: 600;
    margin-bottom: 4px;
  }

  .channel {
    display: flex;
    align-items: center;
    gap: 4px;
    padding: 2px 0;
  }

  .inputs .channel {
    justify-content: flex-start;
  }

  .outputs .channel {
    justify-content: flex-end;
  }

  .channel-dot {
    font-size: 8px;
  }

  .channel-dot.input {
    color: #10b981;
  }

  .channel-dot.output {
    color: #3b82f6;
  }

  .channel-name {
    color: #334155;
    font-family: monospace;
    font-size: 10px;
  }

  .state-preview {
    border-top: 1px solid #e2e8f0;
    padding-top: 6px;
    margin-top: 6px;
  }

  .state-title {
    font-size: 9px;
    text-transform: uppercase;
    color: #64748b;
    font-weight: 600;
    margin-bottom: 4px;
  }

  .state-item {
    display: flex;
    justify-content: space-between;
    padding: 1px 0;
  }

  .state-key {
    color: #64748b;
    font-family: monospace;
    font-size: 9px;
  }

  .state-value {
    color: #0f172a;
    font-family: monospace;
    font-size: 9px;
    font-weight: 500;
  }
</style>
