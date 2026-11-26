import 'package:flutter/material.dart';

IconData scenarioIcon(String name) => switch (name) {
      'local_cafe' => Icons.local_cafe_rounded,
      'local_pizza' => Icons.local_pizza_rounded,
      'local_shipping' => Icons.local_shipping_rounded,
      'shopping_bag' => Icons.shopping_bag_rounded,
      'hotel' => Icons.hotel_rounded,
      'photo_camera' => Icons.photo_camera_rounded,
      'park' => Icons.park_rounded,
      'card_giftcard' => Icons.card_giftcard_rounded,
      'family_restroom' => Icons.family_restroom_rounded,
      'pets' => Icons.pets_rounded,
      'wb_sunny' => Icons.wb_sunny_rounded,
      _ => Icons.auto_awesome_rounded,
    };

const kXiaolanSticker = 'assets/images/mascot/xiaolan-roleplay-sticker.png';
