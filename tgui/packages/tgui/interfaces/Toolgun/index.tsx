import { type ReactNode, useEffect, useMemo, useState } from 'react';
import { Stack } from 'tgui-core/components';

import { useBackend } from '../../backend';
import { Window } from '../../layouts';
import { BuildMode } from './modes/BuildMode';
import { ColorMode } from './modes/ColorMode';
import { ModeTabs } from './modes/ModeTabs';
import { ResizeMode } from './modes/ResizeMode';
import { SpawnMode } from './modes/SpawnMode';
import type { ToolgunData, ToolgunTypeNode } from './types';

type ActFn = (action: string, payload?: Record<string, unknown>) => void;

type ToolgunViewModel = {
  act: ActFn;
  data: ToolgunData;
  modeKey: string;
  search: string;
  normalizedSearch: string;
  selectedPath: string;
  visibleObjects: ToolgunData['objects'];
  selectedEntry: ToolgunData['objects'][number] | undefined;
  currentBrowsePath: string;
  childrenByParent: Record<string, ToolgunTypeNode[]>;
  currentChildNodes: ToolgunTypeNode[];
  onSearchChange: (value: string) => void;
};

abstract class ModeRenderer {
  abstract canRender(modeKey: string): boolean;
  abstract render(vm: ToolgunViewModel): ReactNode;
}

class SpawnModeRenderer extends ModeRenderer {
  canRender(modeKey: string): boolean {
    return modeKey === 'spawn' || modeKey === 'mobs';
  }

  render(vm: ToolgunViewModel): ReactNode {
    const d = vm.data;
    return (
      <SpawnMode
        act={vm.act}
        modeKey={vm.modeKey}
        search={vm.search}
        normalizedSearch={vm.normalizedSearch}
        hasMore={d.has_more ?? false}
        visibleCount={d.visible_count ?? 0}
        matchCount={d.match_count ?? 0}
        selectedEntry={vm.selectedEntry}
        selectedPath={vm.selectedPath}
        visibleObjects={vm.visibleObjects}
        currentBrowsePath={vm.currentBrowsePath}
        childrenByParent={vm.childrenByParent}
        currentChildNodes={vm.currentChildNodes}
        useCustomColor={d.use_custom_color ?? false}
        customColor={d.custom_color ?? '#FFFFFF'}
        customDensity={d.custom_density ?? false}
        customOpacity={d.custom_opacity ?? false}
        customIndestructible={d.custom_indestructible ?? false}
        mob_ai_controller={d.mob_ai_controller}
        mob_max_health={d.mob_max_health}
        mob_health={d.mob_health}
        mob_bodytemperature={d.mob_bodytemperature}
        mob_min_temperature={d.mob_min_temperature}
        mob_max_temperature={d.mob_max_temperature}
        mob_need_atmosphere={d.mob_need_atmosphere}
        mob_unsuitable_atmos_damage={d.mob_unsuitable_atmos_damage}
        mob_melee_damage_lower={d.mob_melee_damage_lower}
        mob_melee_damage_upper={d.mob_melee_damage_upper}
        onSearchChange={vm.onSearchChange}
      />
    );
  }
}

class BuildModeRenderer extends ModeRenderer {
  canRender(modeKey: string): boolean {
    return modeKey === 'build';
  }

  render(vm: ToolgunViewModel): ReactNode {
    const d = vm.data;
    return (
      <BuildMode
        act={vm.act}
        search={vm.search}
        normalizedSearch={vm.normalizedSearch}
        hasMore={d.has_more ?? false}
        visibleCount={d.visible_count ?? 0}
        matchCount={d.match_count ?? 0}
        selectedPath={vm.selectedPath}
        selectedEntry={vm.selectedEntry}
        turfs={d.turfs ?? []}
        currentBrowsePath={vm.currentBrowsePath}
        childrenByParent={vm.childrenByParent}
        currentChildNodes={vm.currentChildNodes}
        buildAction={d.build_action ?? 'brush'}
        wandRange={d.wand_range ?? 3}
        useCustomColor={d.use_custom_color ?? false}
        customColor={d.custom_color ?? '#FFFFFF'}
        customDensity={d.custom_density ?? false}
        customOpacity={d.custom_opacity ?? false}
        customIndestructible={d.custom_indestructible ?? false}
        onSearchChange={vm.onSearchChange}
      />
    );
  }
}

class ColorModeRenderer extends ModeRenderer {
  canRender(modeKey: string): boolean {
    return modeKey === 'color';
  }

  render(vm: ToolgunViewModel): ReactNode {
    return (
      <ColorMode
        act={vm.act}
        selectedColor={vm.data.selected_color ?? '#FFFFFF'}
      />
    );
  }
}

class ResizeModeRenderer extends ModeRenderer {
  canRender(modeKey: string): boolean {
    return modeKey === 'resize';
  }

  render(vm: ToolgunViewModel): ReactNode {
    return <ResizeMode act={vm.act} scaleValue={vm.data.scale_value ?? 1} />;
  }
}

const MODE_RENDERERS: ModeRenderer[] = [
  new SpawnModeRenderer(),
  new BuildModeRenderer(),
  new ColorModeRenderer(),
  new ResizeModeRenderer(),
];

export function Toolgun() {
  const { act, data } = useBackend<ToolgunData>();
  const modeKey = data.mode_key ?? 'generic';

  const [search, setSearch] = useState(data.search ?? '');
  const [debouncedSearch, setDebouncedSearch] = useState(data.search ?? '');

  useEffect(() => {
    const timer = setTimeout(() => setDebouncedSearch(search), 350);
    return () => clearTimeout(timer);
  }, [search]);

  useEffect(() => {
    const backendSearch = data.search ?? '';
    if (debouncedSearch !== backendSearch) {
      act('set_search', { search: debouncedSearch });
    }
  }, [debouncedSearch, data.search, act]);

  useEffect(() => {
    const backendSearch = data.search ?? '';
    setSearch(backendSearch);
    setDebouncedSearch(backendSearch);
  }, [data.search, modeKey]);

  const normalizedSearch = debouncedSearch.trim().toLowerCase();
  const selectedPath =
    modeKey === 'build'
      ? (data.selected_turf ?? '')
      : (data.selected_type ?? '');
  const visibleObjects =
    modeKey === 'build' ? (data.turfs ?? []) : (data.objects ?? []);
  const selectedEntry = visibleObjects.find(
    (entry) => entry.type === selectedPath,
  );
  const currentBrowsePath =
    data.browse_path ??
    (modeKey === 'build' ? '/turf' : modeKey === 'mobs' ? '/mob' : '/obj');

  const childrenByParent = useMemo<Record<string, ToolgunTypeNode[]>>(() => {
    const map: Record<string, ToolgunTypeNode[]> = {};
    Object.values(data.type_nodes ?? {}).forEach((node) => {
      if (!node.parent) {
        return;
      }
      map[node.parent] = map[node.parent] || [];
      map[node.parent].push(node);
    });
    return map;
  }, [data.type_nodes]);

  const currentChildNodes = childrenByParent[currentBrowsePath] || [];

  const vm: ToolgunViewModel = {
    act,
    data,
    modeKey,
    search,
    normalizedSearch,
    selectedPath,
    visibleObjects,
    selectedEntry,
    currentBrowsePath,
    childrenByParent,
    currentChildNodes,
    onSearchChange: setSearch,
  };

  const activeRenderer = MODE_RENDERERS.find((renderer) =>
    renderer.canRender(modeKey),
  );

  return (
    <Window width={1120} height={700} title={data.mode_name || 'Toolgun'}>
      <Window.Content style={{ backgroundColor: '#333333' }}>
        <Stack vertical fill>
          <Stack.Item>
            <ModeTabs
              act={act}
              modeName={data.mode_name || 'Toolgun'}
              modeDesc={data.mode_desc || ''}
              selectedModeKey={data.selected_mode_key || modeKey}
              availableModes={data.available_modes || []}
            />
          </Stack.Item>
          {activeRenderer?.render(vm) || null}
        </Stack>
      </Window.Content>
    </Window>
  );
}
