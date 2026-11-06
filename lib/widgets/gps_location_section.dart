import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GpsLocationSection extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController latController;
  final TextEditingController lngController;
  final bool isGettingLocation;
  final VoidCallback onCurrentGps;
  final VoidCallback onPickMap;

  const GpsLocationSection({
    super.key,
    required this.nameController,
    required this.latController,
    required this.lngController,
    required this.isGettingLocation,
    required this.onCurrentGps,
    required this.onPickMap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GPS LOCATION (required)', style: AppText.dialogSection),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.border, width: AppBorder.width),
            borderRadius: BorderRadius.circular(AppBorder.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: latController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      style: AppText.input,
                      decoration: InputDecoration(
                        labelText: 'Latitude',
                        hintText: '38.123456',
                        hintStyle: AppText.inputHint,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: AppSize.fieldPadding,
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: lngController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      style: AppText.input,
                      decoration: InputDecoration(
                        labelText: 'Longitude',
                        hintText: '-78.123456',
                        hintStyle: AppText.inputHint,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
                        filled: true,
                        fillColor: AppColors.white,
                        contentPadding: AppSize.fieldPadding,
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isGettingLocation ? null : onCurrentGps,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.buttonBg,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
                        ),
                        child: isGettingLocation
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                            : const Text('Device GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: onPickMap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.buttonBg,
                          foregroundColor: AppColors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
                        ),
                        child: const Text('Map GPS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('PLACE NAME (required)', style: AppText.dialogSection),
              const SizedBox(height: 6),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.words,
                style: AppText.input,
                decoration: InputDecoration(
                  hintText: 'e.g. Great campsite',
                  hintStyle: AppText.inputHint,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
                  filled: true,
                  fillColor: AppColors.white,
                  contentPadding: AppSize.fieldPadding,
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
