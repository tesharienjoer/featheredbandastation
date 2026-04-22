import { CheckboxInput, type FeatureToggle } from '../base';

export const daylight_tint_fx: FeatureToggle = {
  name: 'Daylight tint effects',
  category: 'UI',
  description: 'Enable smooth day/night color grading on the lighting plane.',
  component: CheckboxInput,
};

export const daylight_particle_fx: FeatureToggle = {
  name: 'Daylight particle weather',
  category: 'UI',
  description: 'Enable client-side rain/snow/dust particles for daylight weather.',
  component: CheckboxInput,
};
