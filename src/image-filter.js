import React from 'react';
import PropTypes from 'prop-types';
import { defaultStyle, checkStyle } from './style';
import { requireNativeComponent, View } from 'react-native';

const anyToString = n => `${n}`;
const pointToArray = p => [`${p.x}`, `${p.y}`];

const NativeImageFilter = requireNativeComponent(
  'RNImageFilter',
  { name: 'NativeImageFilter' },
  {
    nativeOnly: {
      nativeBackgroundAndroid: true,
      nativeForegroundAndroid: true,
    }
  }
);

export default ({ style, children, ...restProps }) => {
  checkStyle(style);

  const {
    inputRadius,
    inputWidth,
    inputCenter,
    inputPoint0,
    inputPoint1,
    ...restInputs
  } = restProps;

  const props = {
    ...(inputRadius ? { inputRadius: anyToString(inputRadius) } : {}),
    ...(inputWidth ? { inputWidth: anyToString(inputWidth) } : {}),
    ...(inputCenter ? { inputCenter: pointToArray(inputCenter) } : {}),
    ...(inputPoint0 ? { inputPoint0: pointToArray(inputPoint0) } : {}),
    ...(inputPoint1 ? { inputPoint1: pointToArray(inputPoint1) } : {}),
    ...restInputs
  };

  return (
    <NativeImageFilter
      style={[defaultStyle.container, style]}
      {...props}
    >
      {children}
    </NativeImageFilter>
  );
};
