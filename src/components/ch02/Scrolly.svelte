<script lang="ts">
  // Minimal scrollytelling helper (pattern from The Pudding's Scrolly.svelte):
  // each direct child is a step; `value` is the index of the step most in view.
  import { onMount, type Snippet } from 'svelte';
  interface Props { value?: number; root?: Element | null; top?: number; bottom?: number; children: Snippet }
  let { value = $bindable(0), root = null, top = 0, bottom = 0, children }: Props = $props();
  let container: HTMLDivElement;
  const thresholds = Array.from({ length: 101 }, (_, i) => i / 100);

  onMount(() => {
    const steps = Array.from(container.children) as HTMLElement[];
    const ratios = new Array(steps.length).fill(0);
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) ratios[steps.indexOf(e.target as HTMLElement)] = e.intersectionRatio;
        let best = -1, bestR = 0;
        ratios.forEach((r, i) => { if (r > bestR) { bestR = r; best = i; } });
        if (best >= 0) value = best;
      },
      { root, rootMargin: `${-top}px 0px ${-bottom}px 0px`, threshold: thresholds },
    );
    steps.forEach((s) => io.observe(s));
    return () => io.disconnect();
  });
</script>

<div bind:this={container} class="scrolly-steps">{@render children()}</div>
