import { useEffect, useMemo, useState } from 'react';
import {
  Box,
  Button,
  Collapsible,
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

  useEffect(() => {
    setSearch(backendSearch);
  }, [backendSearch, mode_key]);

  const normalizedSearch = search.trim().toLowerCase();

  const visibleObjects = mode_key === 'build' ? turfs : objects;

  const topLevelNodes = useMemo(() => Object.values(type_nodes), [type_nodes]);
  const topLevelObjNodes = useMemo(
    () => topLevelNodes.filter((node) => node.parent === '/obj'),
    [topLevelNodes],
  );
  const topLevelTurfNodes = useMemo(
    () => topLevelNodes.filter((node) => node.parent === '/turf'),
    [topLevelNodes],
  );

  const childrenByParent = useMemo(() => {
    const map: Record<string, ToolgunTypeNode[]> = {};
    Object.values(type_nodes).forEach((node) => {
      if (!node.parent) return;
      map[node.parent] = map[node.parent] || [];
      map[node.parent].push(node);
    });
    return map;
  }, [type_nodes]);

  const fallback = <Box width="48px" height="48px" />;

  /** Улучшенный рендер узла дерева (работает и для obj, и для turf) */
  const renderNode = (
    node: ToolgunTypeNode,
    depth = 0,
    isTurf = false,
  ) => {
    const children = childrenByParent[node.id] || [];
    const isSelected = isTurf
      ? selected_turf === node.id
      : selected_type === node.id;

    const onClick = () =>
      act(isTurf ? 'select_turf' : 'select_type', { path: node.id });

    const title = (
      <Button
        fluid
        color={isSelected ? 'grey' : 'transparent'}
        onClick={onClick}
      >
        {node.name}
      </Button>
    );

    if (!children.length) {
      return (
        <Box key={node.id} ml={depth ? 1 : 0}>
          {title}
        </Box>
      );
    }

    return (
      <Box key={node.id} ml={depth ? 1 : 0}>
        <Collapsible title={title} open={depth < 2}>
          {children.map((child) => renderNode(child, depth + 1, isTurf))}
        </Collapsible>
      </Box>
    );
  };

  /** Компактная карточка объекта/турфа в стиле Garry’s Mod (клик по всей карточке = выбор) */
  const renderObjectItem = (
    entry: ToolgunObject,
    onSelect: (path: string) => void,
  ) => (
    <Box
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        padding: '10px',
        backgroundColor: '#383838',
        border: '1px solid #4f4f4f',
        borderRadius: '4px',
        cursor: 'pointer',
        transition: 'background-color 0.1s',
      }}
      onClick={() => onSelect(entry.type)}
    >
      <DmIcon
        icon={entry.icon}
        icon_state={entry.icon_state}
        width="48px"
        fallback={fallback}
      />
      <Box style={{ flexGrow: 1 }} minWidth={0}>
        <Box fontWeight="bold" overflow="hidden" style={{ whiteSpace: 'nowrap' }}>
          {entry.name || entry.type}
        </Box>
        <Box
          color="#a0a0a0"
          fontSize="0.85em"
          mt={0.5}
          overflow="hidden"
          style={{ whiteSpace: 'nowrap' }}
        >
          {entry.type}
        </Box>
      </Box>
    </Box>
  );

  const gridStyle = {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(260px, 1fr))',
    gap: '8px',
  };

  const renderCustomizationSettings = () => (
    <Section title="Настройки спавна / строительства" fill>
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

  const renderSpawnMode = () => (
    <>
      <Stack.Item>
        <Input
          fluid
          placeholder="Поиск по имени или типу..."
          value={search}
          onChange={(value) => {
            setSearch(value);
            act('set_search', { search: value });
          }}
        />
      </Stack.Item>
      <Stack.Item grow>
        <Stack fill>
          {/* Левая панель — дерево типов (минималистично) */}
          <Stack.Item basis="35%">
            <Section fill scrollable title="Дерево типов">
              <Box mb={1}>
                <Button
                  fluid
                  color={selected_type === '/obj' ? 'grey' : 'transparent'}
                  onClick={() => act('select_type', { path: '/obj' })}
                >
                  obj
                </Button>
              </Box>
              {topLevelObjNodes.map((node) => renderNode(node, 0, false))}
            </Section>
          </Stack.Item>

          {/* Центральная панель — сетка объектов (как в Garry’s Mod) */}
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
              <Box style={gridStyle}>
                {visibleObjects.map((entry) =>
                  renderObjectItem(entry, (path) =>
                    act('select_type', { path }),
                  ),
                )}
              </Box>

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

          {/* Правая панель — настройки */}
          <Stack.Item basis="30%">
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
          placeholder="Поиск по имени или типу поверхности..."
          value={search}
          onChange={(value) => {
            setSearch(value);
            act('set_search', { search: value });
          }}
        />
      </Stack.Item>
      <Stack.Item grow>
        <Stack fill>
          {/* Левая панель — дерево турфов (теперь тоже полноценное иерархическое) */}
          <Stack.Item basis="35%">
            <Section fill scrollable title="Дерево поверхностей">
              <Box mb={1}>
                <Button
                  fluid
                  color={selected_turf === '/turf' ? 'grey' : 'transparent'}
                  onClick={() => act('select_turf', { path: '/turf' })}
                >
                  turf
                </Button>
              </Box>
              {topLevelTurfNodes.map((node) => renderNode(node, 0, true))}
            </Section>
          </Stack.Item>

          {/* Центральная панель — сетка поверхностей */}
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
              <Box style={gridStyle}>
                {visibleObjects.map((entry) =>
                  renderObjectItem(entry, (path) =>
                    act('select_turf', { path }),
                  ),
                )}
              </Box>

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

          {/* Правая панель — режимы строительства + настройки */}
          <Stack.Item basis="30%">
            <Section title="Режим строительства">
              <Stack vertical>
                <Stack.Item>
                  <Button
                    fluid
                    selected={build_action === 'brush'}
                    onClick={() => act('set_build_action', { build_action: 'brush' })}
                  >
                    Кисть
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    fluid
                    selected={build_action === 'fill'}
                    onClick={() => act('set_build_action', { build_action: 'fill' })}
                  >
                    Заливка
                  </Button>
                </Stack.Item>
                <Stack.Item>
                  <Button
                    fluid
                    selected={build_action === 'wand'}
                    onClick={() => act('set_build_action', { build_action: 'wand' })}
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
                          onChange={(value) => act('set_wand_range', { range: value })}
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
                <Button
                  fluid
                  onClick={() => act('set_scale', { scale: 0.5 })}
                >
                  0.5×
                </Button>
              </Stack.Item>
              <Stack.Item grow>
                <Button
                  fluid
                  onClick={() => act('set_scale', { scale: 1 })}
                >
                  1×
                </Button>
              </Stack.Item>
              <Stack.Item grow>
                <Button
                  fluid
                  onClick={() => act('set_scale', { scale: 2 })}
                >
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
    <Window
      width={1120}
      height={640}
      title={mode_name || 'Toolgun'}
      // Убрали «hackerman» — теперь чистый минималистичный серый стиль под Garry’s Mod
    >
      <Window.Content
        style={{
          background: '#252525', // тёмно-серый фон в духе Garry’s Mod
        }}
      >
        <Stack vertical fill>
          {/* Заголовок режима */}
          <Stack.Item>
            <Section title={mode_name || 'Toolgun'}>
              <Box color="#d2d2d2">{mode_desc}</Box>
            </Section>
          </Stack.Item>

          {/* Рендер в зависимости от режима */}
          {mode_key === 'spawn' && renderSpawnMode()}
          {mode_key === 'build' && renderBuildMode()}
          {mode_key === 'color' && renderColorMode()}
          {mode_key === 'resize' && renderResizeMode()}
        </Stack>
      </Window.Content>
    </Window>
  );
}
