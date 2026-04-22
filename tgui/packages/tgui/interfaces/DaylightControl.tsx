import { Button, NumberInput, Section, Stack } from 'tgui-core/components';
import type { BooleanLike } from 'tgui-core/react';
import { useBackend } from '../backend';
import { Window } from '../layouts';

type Data = {
  cycle_locked: BooleanLike;
  time_locked: BooleanLike;
  manual_time: number;
  daylight_cycle: number;
  current_intensity: number;
  current_color: string;
  current_phase: string;
  active_weather_count: number;
  visual_weather_mode: string;
};

export const DaylightControl = () => {
  const { act, data } = useBackend<Data>();
  const {
    cycle_locked,
    manual_time,
    daylight_cycle,
    current_intensity,
    current_color,
    current_phase,
    active_weather_count,
    visual_weather_mode,
  } = data;

  return (
    <Window title="Daylight Control" width={420} height={360}>
      <Window.Content scrollable>
        <Section title="Current State">
          <Stack vertical>
            <Stack.Item>Phase: {current_phase}</Stack.Item>
            <Stack.Item>Intensity: {current_intensity.toFixed(2)}</Stack.Item>
            <Stack.Item>Color: {current_color}</Stack.Item>
            <Stack.Item>Active weather: {active_weather_count}</Stack.Item>
            <Stack.Item>Visual mode: {visual_weather_mode}</Stack.Item>
          </Stack>
        </Section>

        <Section title="Day/Night Cycle">
          <Stack vertical>
            <Stack.Item>
              <Stack align="center">
                <Stack.Item grow>Cycle length (minutes)</Stack.Item>
                <Stack.Item>
                  <NumberInput
                    minValue={5}
                    maxValue={240}
                    step={1}
                    value={daylight_cycle}
                    onChange={(value) =>
                      act('set_cycle_minutes', { value: Math.round(value) })
                    }
                  />
                </Stack.Item>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Stack align="center">
                <Stack.Item grow>Manual intensity (-1 = auto)</Stack.Item>
                <Stack.Item>
                  <NumberInput
                    minValue={-1}
                    maxValue={1}
                    step={0.01}
                    value={manual_time}
                    onChange={(value) =>
                      act('set_manual', { value: Number(value.toFixed(2)) })
                    }
                  />
                </Stack.Item>
              </Stack>
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="lock"
                selected={!!cycle_locked}
                content={cycle_locked ? 'Cycle locked' : 'Cycle unlocked'}
                onClick={() => act('toggle_cycle_lock')}
              />
              <Button
                ml={1}
                icon="rotate-left"
                content="Return to auto"
                onClick={() => act('set_auto')}
              />
            </Stack.Item>
          </Stack>
        </Section>

        <Section title="Weather Control">
          <Stack>
            <Stack.Item>
              <Button
                icon="cloud-rain"
                content="Start rain"
                onClick={() => act('start_weather', { weather_type: 'rain' })}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="snowflake"
                content="Start snow"
                onClick={() => act('start_weather', { weather_type: 'snow' })}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="radiation"
                content="Start dust"
                onClick={() =>
                  act('start_weather', { weather_type: 'radiation' })
                }
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="smog"
                content="Start mist"
                onClick={() => act('start_weather', { weather_type: 'mist' })}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                icon="shuffle"
                content="Auto mode"
                onClick={() => act('start_weather', { weather_type: 'auto' })}
              />
            </Stack.Item>
            <Stack.Item>
              <Button
                color="bad"
                icon="xmark"
                content="Stop weather"
                onClick={() => act('stop_weather')}
              />
            </Stack.Item>
          </Stack>
        </Section>
      </Window.Content>
    </Window>
  );
};
