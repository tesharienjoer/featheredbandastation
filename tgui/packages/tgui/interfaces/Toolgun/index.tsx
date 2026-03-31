import { useEffect, useMemo, useState } from 'react';
import {
  Box,
  Button,
  DmIcon,
  Input,
  Section,
  Stack,
} from 'tgui-core/components';

import { useBackend } from '../../backend';
import { Window } from '../../layouts';

type ToolgunTypeNode = {
  id: string;
  parent: string;
  name: string;
};

type ToolgunObject = {
  type: string;
  name: string;
  icon: string;
  icon_state: string;
};

type ToolgunData = {
  mode_name: string;
  mode_desc: string;
  mode_key?: string;
  selected_type?: string;
  selected_turf?: string;
  browse_path?: string;
  search?: string;
  has_more?: boolean;
  visible_count?: number;
  match_count?: number;
  use_custom_color?: boolean;
  custom_color?: string;
  custom_density?: boolean;
  custom_opacity?: boolean;
  custom_indestructible?: boolean;
  build_action?: 'brush' | 'fill' | 'wand';
  wand_range?: number;
  selected_color?: string;
  scale_value?: number;
  type_nodes: Record<string, ToolgunTypeNode>;
  objects: ToolgunObject[];
  turfs?: ToolgunObject[];
};

export function Toolgun() {
  const { act, data } = useBackend<ToolgunData>();
  const {
    mode_name,
    mode_desc,
    mode_key = 'generic',
    selected_type = '',
    selected_turf = '',
    browse_path: backendBrowsePath = '',
    type_nodes = {},
    objects = [],
    turfs = [],
    has_more = false,
    visible_count = 0,
    match_count = 0,
    use_custom_color = false,
    custom_color = '#FFFFFF',
    custom_density = false,
    custom_opacity = false,
    custom_indestructible = false,
    build_action = 'brush',
    wand_range = 3,
    selected_color = '#FFFFFF',
    scale_value = 1,
    search: backendSearch = '',
  } = data;

  const [search, setSearch] = useState(backendSearch);

  const [debouncedSearch, setDebouncedSearch] = useState(backendSearch);

  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedSearch(search);
    }, 350);

    return () => clearTimeout(timer);
  }, [search]);

  useEffect(() => {
    if (debouncedSearch !== backendSearch) {
      act('set_search', { search: debouncedSearch });
    }
  }, [debouncedSearch, backendSearch, act]);

  useEffect(() => {
    setSearch(backendSearch);
    setDebouncedSearch(backendSearch);
  }, [backendSearch, mode_key]);

  const normalizedSearch = debouncedSearch.trim().toLowerCase();

  const visibleObjects = mode_key === 'build' ? turfs : objects;
  const selectedPath = mode_key === 'build' ? selected_turf : selected_type;
  const selectedEntry = visibleObjects.find(
    (entry) => entry.type === selectedPath,
  );

  const currentBrowsePath =
    backendBrowsePath || (mode_key === 'build' ? '/turf' : '/obj');

  const topLevelNodes = useMemo(() => Object.values(type_nodes), [type_nodes]);
  const childrenByParent = useMemo(() => {
    const map: Record<string, ToolgunTypeNode[]> = {};
    Object.values(type_nodes).forEach((node) => {
      if (!node.parent) return;
      map[node.parent] = map[node.parent] || [];
      map[node.parent].push(node);
    });
    return map;
  }, [type_nodes]);

  const currentChildNodes = childrenByParent[currentBrowsePath] || [];
  const filteredChildNodes = normalizedSearch
    ? currentChildNodes.filter(
        (node) =>
          node.name.toLowerCase().includes(normalizedSearch) ||
          node.id.toLowerCase().includes(normalizedSearch),
      )
    : currentChildNodes;

  const fallback = <Box width="48px" height="48px" />;

  const gridStyle = {
    display: 'grid',
    gridTemplateColumns: 'repeat(5, 1fr)',
    gap: '8px',
  };

  /** Большой превью выбранного объекта */
  const renderSelectedPreview = () => {
    if (!selectedEntry) {
      return (
        <Section title="Выбранный объект" mb={2}>
          <Box
            textAlign="center"
            color="#aaaaaa"
            py={6}
            backgroundColor="#444444"
            style={{ borderRadius: '4px' }}
          >
            Ничего не выбрано
          </Box>
        </Section>
      );
    }

    return (
      <Section title="Выбранный объект" mb={2}>
        <Stack align="center">
          <Stack.Item grow>
            <DmIcon
              position="center"
              icon={selectedEntry.icon}
              icon_state={selectedEntry.icon_state}
              width="128px"
              fallback={fallback}
            />
            <Box minWidth={0}>
              <Box
                fontWeight="bold"
                fontSize="1.3em"
                lineHeight={1.2}
                overflow="hidden"
                style={{ whiteSpace: 'nowrap' }}
              >
                {selectedEntry.name ||
                  selectedEntry.type.split('/').pop() ||
                  selectedEntry.type}
              </Box>
            </Box>
          </Stack.Item>
        </Stack>
      </Section>
    );
  };

  const renderObjectsGrid = (onSelect: (path: string) => void) => (
    <Box style={gridStyle}>
      {visibleObjects.map((entry) => {
        const isSelected = selectedPath === entry.type;
        return (
          <Box
            key={entry.type}
            style={{
              display: 'flex',
              alignItems: 'center',
              gap: '1em',
              padding: '2px',
              backgroundColor: isSelected ? '#666666' : '#444444',
              border: `1px solid ${isSelected ? '#999999' : '#555555'}`,
              borderRadius: '2px',
              cursor: 'pointer',
            }}
          >
            <Button
              tooltip={entry.name || entry.type.split('/').pop() || entry.type}
              onDoubleClick={() => onSelect(entry.type)}
              backgroundColor="transparent"
            >
              <DmIcon
                icon={entry.icon}
                icon_state={entry.icon_state}
                width="48px"
                fallback={fallback}
                backgroundColor={isSelected ? '#666666' : '#444444'}
              />
            </Button>
          </Box>
        );
      })}
    </Box>
  );

  const renderCustomizationSettings = () => (
    <Section title="Настройки" scrollable>
      <Stack vertical>
        <Stack.Item>
          <Button.Checkbox
            checked={use_custom_color}
            content="Использовать свой цвет"
            onClick={() => act('toggle_use_custom_color')}
          />
        </Stack.Item>
        <Stack.Item>
          <Stack>
            <Stack.Item grow>
              <Input
                fluid
                value={custom_color}
                onChange={(value) => act('set_custom_color', { color: value })}
              />
            </Stack.Item>
            <Stack.Item>
              <Button icon="palette" onClick={() => act('pick_custom_color')}>
                Выбрать
              </Button>
            </Stack.Item>
          </Stack>
        </Stack.Item>
        <Stack.Item>
          <Button.Checkbox
            checked={custom_density}
            content="Плотность включена"
            onClick={() => act('toggle_custom_density')}
          />
        </Stack.Item>
        <Stack.Item>
          <Button.Checkbox
            checked={custom_opacity}
            content="Непрозрачность включена"
            onClick={() => act('toggle_custom_opacity')}
          />
        </Stack.Item>
        <Stack.Item>
          <Button.Checkbox
            checked={custom_indestructible}
            content="Неразрушимый"
            onClick={() => act('toggle_custom_indestructible')}
          />
        </Stack.Item>
      </Stack>
    </Section>
  );

  /** Левая панель — навигация по папкам */
  const renderFolderBrowser = (isTurf: boolean) => {
    const rootPath = isTurf ? '/turf' : '/obj';
    const title = isTurf ? 'Подтипы турфов' : 'Подтипы объектов';
    const onRootClick = () => act('browse_to', { path: rootPath });

    let displayChildNodes = currentChildNodes;
    if (normalizedSearch) {
      displayChildNodes = currentChildNodes.filter(
        (node) =>
          node.name.toLowerCase().includes(normalizedSearch) ||
          node.id.toLowerCase().includes(normalizedSearch),
      );
    }

    const folderChildNodes = displayChildNodes.filter((node) => {
      return !!(
        childrenByParent[node.id] && childrenByParent[node.id].length > 0
      );
    });

    return (
      <Section fill scrollable title={title}>
        {currentBrowsePath !== rootPath && (
          <Button
            fluid
            icon="arrow-up"
            mb={1}
            backgroundColor="transparent"
            onClick={() => {
              const lastSlash = currentBrowsePath.lastIndexOf('/');
              const parentPath =
                lastSlash > 0
                  ? currentBrowsePath.slice(0, lastSlash)
                  : rootPath;
              act('browse_to', { path: parentPath });
            }}
          >
            .. Назад
          </Button>
        )}

        <Box mb={1}>
          <Button
            fluid
            color={currentBrowsePath === rootPath ? 'grey' : 'transparent'}
            onClick={onRootClick}
          >
            {isTurf ? 'turf (корень)' : 'obj (корень)'}
          </Button>
        </Box>

        {folderChildNodes.map((node) => (
          <Button
            key={node.id}
            fluid
            mb={0.5}
            color="transparent"
            onClick={() => act('browse_to', { path: node.id })}
          >
            {node.name}
          </Button>
        ))}

        {folderChildNodes.length === 0 && (
          <Box color="#888888" textAlign="center" py={4}>
            {normalizedSearch
              ? 'Подтипы не обнаружены'
              : 'У этого типа нет подтипов'}
          </Box>
        )}
      </Section>
    );
  };

  const renderSpawnMode = () => (
    <>
      <Stack.Item>
        <Input
          fluid
          placeholder="Поиск по всем типам и именам..."
          value={search}
          onChange={(value) => setSearch(value)}
        />
      </Stack.Item>
      <Stack.Item grow>
        <Stack fill>
          <Stack.Item basis="280px">{renderFolderBrowser(false)}</Stack.Item>

          <Stack.Item grow>
            <Section
              fill
              scrollable
              title="Объекты"
              buttons={
                <Button icon="plus" onClick={() => act('spawn_here')}>
                  Заспавнить здесь
                </Button>
              }
            >
              {renderObjectsGrid((path) => act('select_type', { path }))}

              {!normalizedSearch && has_more && (
                <Button
                  fluid
                  icon="download"
                  mt={2}
                  onClick={() => act('load_more')}
                >
                  Загрузить ещё ({visible_count}/{match_count})
                </Button>
              )}
            </Section>
          </Stack.Item>

          <Stack.Item basis="280px">
            {renderSelectedPreview()}
            {renderCustomizationSettings()}
          </Stack.Item>
        </Stack>
      </Stack.Item>
    </>
  );

  const renderBuildMode = () => (
    <>
      <Stack.Item>
        <Input
          fluid
          placeholder="Поиск по всем типам и именам турфов..."
          value={search}
          onChange={(value) => setSearch(value)}
        />
      </Stack.Item>
      <Stack.Item grow>
        <Stack fill>
          <Stack.Item basis="280px">{renderFolderBrowser(true)}</Stack.Item>

          <Stack.Item grow>
            <Section
              fill
              scrollable
              title="Поверхности"
              buttons={
                <Button icon="paint-brush" onClick={() => act('build_here')}>
                  Построить здесь
                </Button>
              }
            >
              {renderObjectsGrid((path) => act('select_turf', { path }))}

              {!normalizedSearch && has_more && (
                <Button
                  fluid
                  icon="download"
                  mt={2}
                  onClick={() => act('load_more')}
                >
                  Загрузить ещё ({visible_count}/{match_count})
                </Button>
              )}
            </Section>
          </Stack.Item>

          <Stack.Item basis="280px">
            {renderSelectedPreview()}

            <Section title="Режим строительства" mb={2}>
              <Stack vertical>
                <Stack.Item>
                  <Button
                    fluid
                    color={build_action === 'brush' ? 'grey' : 'transparent'}
                    onClick={() =>
                      act('set_build_action', { build_action: 'brush' })
                    }
                  >
                    Кисть
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    fluid
                    color={build_action === 'fill' ? 'grey' : 'transparent'}
                    onClick={() =>
                      act('set_build_action', { build_action: 'fill' })
                    }
                  >
                    Заливка
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    fluid
                    color={build_action === 'wand' ? 'grey' : 'transparent'}
                    onClick={() =>
                      act('set_build_action', { build_action: 'wand' })
                    }
                  >
                    Палочка
                  </Button>
                </Stack.Item>

                {build_action === 'wand' && (
                  <Stack.Item>
                    <Stack align="center">
                      <Stack.Item>
                        <Box color="#d2d2d2" width="110px">
                          Диапазон:
                        </Box>
                      </Stack.Item>
                      <Stack.Item grow>
                        <Input
                          fluid
                          value={String(wand_range)}
                          onChange={(value) =>
                            act('set_wand_range', { range: value })
                          }
                        />
                      </Stack.Item>
                    </Stack>
                  </Stack.Item>
                )}

                <Stack.Item>
                  <Box color="#d2d2d2" fontSize="0.9em">
                    ЛКМ: применить действие • ПКМ: взять тип поверхности
                  </Box>
                </Stack.Item>
              </Stack>
            </Section>

            {renderCustomizationSettings()}
          </Stack.Item>
        </Stack>
      </Stack.Item>
    </>
  );

  const renderColorMode = () => (
    <Stack.Item grow>
      <Section
        fill
        title="Настройки цвета"
        buttons={
          <Button icon="palette" onClick={() => act('pick_color')}>
            Выбрать цвет
          </Button>
        }
      >
        <Stack vertical>
          <Stack.Item>
            <Input
              fluid
              value={selected_color}
              onChange={(value) => act('set_color', { color: value })}
            />
          </Stack.Item>
          <Stack.Item>
            <Box color={selected_color} fontSize="1.1em">
              Текущий цвет: {selected_color}
            </Box>
          </Stack.Item>
          <Stack.Item>
            <Box color="#d2d2d2" fontSize="0.9em">
              ЛКМ: применить цвет к объекту • ПКМ: сбросить цвет объекта
            </Box>
          </Stack.Item>
        </Stack>
      </Section>
    </Stack.Item>
  );

  const renderResizeMode = () => (
    <Stack.Item grow>
      <Section fill title="Настройки размера">
        <Stack vertical>
          <Stack.Item>
            <Input
              fluid
              value={String(scale_value)}
              onChange={(value) => act('set_scale', { scale: value })}
            />
          </Stack.Item>
          <Stack.Item>
            <Box color="#d2d2d2" fontSize="0.9em">
              ЛКМ: изменить размер на ×{scale_value} • ПКМ: сбросить масштаб
            </Box>
          </Stack.Item>
          <Stack.Item>
            <Stack>
              <Stack.Item grow>
                <Button fluid onClick={() => act('set_scale', { scale: 0.5 })}>
                  0.5×
                </Button>
              </Stack.Item>
              <Stack.Item grow>
                <Button fluid onClick={() => act('set_scale', { scale: 1 })}>
                  1×
                </Button>
              </Stack.Item>
              <Stack.Item grow>
                <Button fluid onClick={() => act('set_scale', { scale: 2 })}>
                  2×
                </Button>
              </Stack.Item>
            </Stack>
          </Stack.Item>
        </Stack>
      </Section>
    </Stack.Item>
  );

  return (
    <Window width={1120} height={640} title={mode_name || 'Toolgun'}>
      <Window.Content
        style={{
          background: '#333333',
        }}
      >
        <Stack vertical fill>
          <Stack.Item>
            <Section title={mode_name || 'Toolgun'}>
              <Box color="#d2d2d2">{mode_desc}</Box>
            </Section>
          </Stack.Item>

          {mode_key === 'spawn' && renderSpawnMode()}
          {mode_key === 'build' && renderBuildMode()}
          {mode_key === 'color' && renderColorMode()}
          {mode_key === 'resize' && renderResizeMode()}
        </Stack>
      </Window.Content>
    </Window>
  );
}
