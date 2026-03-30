import { useMemo, useState } from 'react';
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
  search?: string;
  has_more?: boolean;
  visible_count?: number;
  match_count?: number;
  selected_color?: string;
  scale_value?: number;
  type_nodes: Record<string, ToolgunTypeNode>;
  objects: ToolgunObject[];
};

export const Toolgun = () => {
  const { act, data } = useBackend<ToolgunData>();
  const {
    mode_name,
    mode_desc,
    mode_key = 'generic',
    selected_type = '',
    type_nodes = {},
    objects = [],
    has_more = false,
    visible_count = 0,
    match_count = 0,
    selected_color = '#FFFFFF',
    scale_value = 1,
  } = data;
  const [search, setSearch] = useState('');

  const normalizedSearch = search.trim().toLowerCase();

  const visibleObjects = objects;

  const topLevelNodes = useMemo(
    () => Object.values(type_nodes).filter((node) => node.parent === '/obj'),
    [type_nodes],
  );

  const childrenByParent = useMemo(() => {
    const map: Record<string, ToolgunTypeNode[]> = {};
    Object.values(type_nodes).forEach((node) => {
      if (!node.parent) {
        return;
      }
      map[node.parent] = map[node.parent] || [];
      map[node.parent].push(node);
    });
    return map;
  }, [type_nodes]);

  const fallback = <Box width="32px" height="32px" />;

  const renderNode = (node: ToolgunTypeNode, depth = 0) => {
    const children = childrenByParent[node.id] || [];
    const title = (
      <Button
        fluid
        color={selected_type === node.id ? 'grey' : 'transparent'}
        onClick={() => act('select_type', { path: node.id })}
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
          {children.map((child) => renderNode(child, depth + 1))}
        </Collapsible>
      </Box>
    );
  };

  const renderSpawnMode = () => (
    <>
      <Stack.Item>
        <Input
          fluid
          placeholder="Search by name or type..."
          value={search}
          onChange={(value) => {
            setSearch(value);
            act('set_search', { search: value });
          }}
        />
      </Stack.Item>
      <Stack.Item grow>
        <Stack fill>
          <Stack.Item basis="42%">
            <Section fill scrollable title="Type graph">
              <Box mb={1}>
                <Button
                  fluid
                  color={selected_type === '/obj' ? 'grey' : 'transparent'}
                  onClick={() => act('select_type', { path: '/obj' })}
                >
                  obj
                </Button>
              </Box>
              {topLevelNodes.map((node) => renderNode(node))}
            </Section>
          </Stack.Item>
          <Stack.Item grow>
            <Section
              fill
              scrollable
              title="Objects"
              buttons={
                <Button icon="plus" onClick={() => act('spawn_here')}>
                  Spawn on me
                </Button>
              }
            >
              <Stack vertical>
                {visibleObjects.map((entry) => (
                    <Stack.Item key={entry.type}>
                      <Section
                        title={entry.name || entry.type}
                        buttons={
                          <Button
                            icon="crosshairs"
                            onClick={() => act('select_type', { path: entry.type })}
                          >
                            Select
                          </Button>
                        }
                      >
                        <Stack align="center">
                          <Stack.Item>
                            <DmIcon
                              icon={entry.icon}
                              icon_state={entry.icon_state}
                              width="32px"
                              fallback={fallback}
                            />
                          </Stack.Item>
                          <Stack.Item grow>
                            <Box color="#dadada">{entry.type}</Box>
                          </Stack.Item>
                        </Stack>
                      </Section>
                    </Stack.Item>
                  ))}
                {!normalizedSearch && has_more && (
                  <Stack.Item>
                    <Button fluid icon="download" onClick={() => act('load_more')}>
                      Load more ({visible_count}/{match_count})
                    </Button>
                  </Stack.Item>
                )}
              </Stack>
            </Section>
          </Stack.Item>
        </Stack>
      </Stack.Item>
    </>
  );

  const renderColorMode = () => (
    <Stack.Item grow>
      <Section
        fill
        title="Color Settings"
        buttons={
          <Button icon="palette" onClick={() => act('pick_color')}>
            Pick color
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
            <Box color={selected_color}>Current color: {selected_color}</Box>
          </Stack.Item>
          <Stack.Item>
            <Box color="#d2d2d2">
              LMB: apply selected color to object. RMB: reset object color.
            </Box>
          </Stack.Item>
        </Stack>
      </Section>
    </Stack.Item>
  );

  const renderResizeMode = () => (
    <Stack.Item grow>
      <Section fill title="Resize Settings">
        <Stack vertical>
          <Stack.Item>
            <Input
              fluid
              value={String(scale_value)}
              onChange={(value) => act('set_scale', { scale: value })}
            />
          </Stack.Item>
          <Stack.Item>
            <Box color="#d2d2d2">
              LMB: resize object to factor {scale_value}. RMB: reset object scale.
            </Box>
          </Stack.Item>
          <Stack.Item>
            <Stack>
              <Stack.Item grow>
                <Button fluid onClick={() => act('set_scale', { scale: 0.5 })}>
                  0.5x
                </Button>
              </Stack.Item>
              <Stack.Item grow>
                <Button fluid onClick={() => act('set_scale', { scale: 1 })}>
                  1.0x
                </Button>
              </Stack.Item>
              <Stack.Item grow>
                <Button fluid onClick={() => act('set_scale', { scale: 2 })}>
                  2.0x
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
      width={980}
      height={620}
      title={mode_name || 'Toolgun'}
      theme="hackerman"
    >
      <Window.Content
        style={{
          background: '#4a4a4a',
        }}
      >
        <Stack vertical fill>
          <Stack.Item>
            <Section title={mode_name || 'Toolgun'}>
              <Box color="#d2d2d2">{mode_desc}</Box>
            </Section>
          </Stack.Item>
          {mode_key === 'spawn' && renderSpawnMode()}
          {mode_key === 'color' && renderColorMode()}
          {mode_key === 'resize' && renderResizeMode()}
        </Stack>
      </Window.Content>
    </Window>
  );
};
