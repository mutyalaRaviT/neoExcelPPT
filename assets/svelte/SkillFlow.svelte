<script>
  import { writable } from 'svelte/store';
  import {
    SvelteFlow,
    Controls,
    Background,
    MiniMap
  } from '@xyflow/svelte';
  import '@xyflow/svelte/dist/style.css';
  import SkillNode from './SkillNode.svelte';

  // Props from LiveView
  export let skills = [];
  export let wiring = {};
  export let live;  // LiveSvelte pushEvent

  // Node types
  const nodeTypes = {
    skill: SkillNode
  };

  // Convert skills to nodes
  function skillsToNodes(skills) {
    return skills.map((skill, index) => ({
      id: skill.id,
      type: 'skill',
      position: skill.position || { x: 150 * (index % 4), y: 120 * Math.floor(index / 4) },
      data: {
        label: skill.name,
        skillId: skill.id,
        inputs: skill.inputs || [],
        outputs: skill.outputs || [],
        state: skill.state || {},
        live: live
      }
    }));
  }

  // Convert wiring to edges
  function wiringToEdges(wiring) {
    const edges = [];
    let edgeId = 0;

    for (const [source, targets] of Object.entries(wiring)) {
      // Source format: "skill_id:channel"
      const [sourceSkill, sourceChannel] = source.split(':');

      for (const target of targets) {
        // Target format: "skill_id:channel"
        const [targetSkill, targetChannel] = target.split(':');

        edges.push({
          id: `e${edgeId++}`,
          source: sourceSkill,
          target: targetSkill,
          sourceHandle: sourceChannel,
          targetHandle: targetChannel,
          animated: true,
          style: 'stroke: #3b82f6; stroke-width: 2px;',
          label: `${sourceChannel} → ${targetChannel}`,
          labelStyle: 'font-size: 10px; fill: #64748b;'
        });
      }
    }

    return edges;
  }

  // Reactive stores
  const nodes = writable(skillsToNodes(skills));
  const edges = writable(wiringToEdges(wiring));

  // Update when props change
  $: $nodes = skillsToNodes(skills);
  $: $edges = wiringToEdges(wiring);

  // Handle node position changes
  function onNodesChange(event) {
    nodes.update(n => {
      // Apply the changes
      return n;
    });
  }

  // Handle node drag end - persist position to LiveView
  function onNodeDragStop(event) {
    const { node } = event.detail;
    if (live) {
      live.pushEvent('skill_position_changed', {
        skill_id: node.id,
        position: node.position
      });
    }
  }

  // Handle connection creation
  function onConnect(event) {
    const { connection } = event.detail;
    if (live) {
      live.pushEvent('skill_connected', {
        source: connection.source,
        source_channel: connection.sourceHandle,
        target: connection.target,
        target_channel: connection.targetHandle
      });
    }
  }

  // Handle edge deletion
  function onEdgesDelete(event) {
    const { edges: deletedEdges } = event.detail;
    if (live) {
      for (const edge of deletedEdges) {
        live.pushEvent('skill_disconnected', {
          source: edge.source,
          source_channel: edge.sourceHandle,
          target: edge.target,
          target_channel: edge.targetHandle
        });
      }
    }
  }
</script>

<div class="skill-flow-container" style="width: 100%; height: 600px;">
  <SvelteFlow
    {nodes}
    {edges}
    {nodeTypes}
    fitView
    on:nodeschange={onNodesChange}
    on:nodedragstop={onNodeDragStop}
    on:connect={onConnect}
    on:edgesdelete={onEdgesDelete}
  >
    <Controls />
    <Background variant="dots" gap={12} size={1} />
    <MiniMap
      nodeColor={(node) => {
        switch (node.type) {
          case 'skill': return '#3b82f6';
          default: return '#64748b';
        }
      }}
    />
  </SvelteFlow>
</div>

<style>
  .skill-flow-container {
    border: 1px solid #e2e8f0;
    border-radius: 8px;
    background: #f8fafc;
  }

  :global(.svelte-flow) {
    background: #ffffff;
  }

  :global(.svelte-flow__edge-path) {
    stroke: #3b82f6;
    stroke-width: 2;
  }

  :global(.svelte-flow__edge.animated path) {
    stroke-dasharray: 5;
    animation: dash 0.5s linear infinite;
  }

  @keyframes dash {
    to {
      stroke-dashoffset: -10;
    }
  }
</style>
