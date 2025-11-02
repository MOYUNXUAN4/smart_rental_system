import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

// 导入我们已有的 GlassCard
// ignore: unused_import
import 'glass_card.dart';

// ✅ 1. 在这里定义 ContractOption enum，以便 ContractPicker 和 AddPropertyScreen 都可以访问它
enum ContractOption { none, upload, generate }

// ===================================================================
// --- 所有 UI 逻辑都被封装到这些独立的 StatelessWidget 中 ---
// ===================================================================

// --- 表单输入框 (TextFormField) ---
class PropertyTextFormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final int maxLines;

  const PropertyTextFormField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.icon,
    this.validator,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
      ),
    );
  }
}

// --- 小区下拉菜单 ---
class CommunityDropdown extends StatelessWidget {
  final String? value;
  final bool isLoading;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const CommunityDropdown(
      {super.key,
      this.value,
      required this.isLoading,
      required this.items,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: 'Community / Apartment',
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(
            isLoading ? Icons.hourglass_top : Icons.apartment,
            color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
      ),
      dropdownColor: const Color(0xFF295a68),
      style: const TextStyle(color: Colors.white, fontSize: 16),
      iconEnabledColor: Colors.white70,
      isExpanded: true,
      hint: Text(isLoading ? 'Loading communities...' : 'Select community',
          style: const TextStyle(color: Colors.white70)),
      validator: (value) =>
          value == null ? 'Please select a community' : null,
      onChanged: isLoading ? null : onChanged,
      items: items.map((String value) {
        return DropdownMenuItem<String>(
          value: value,
          child: Text(value, overflow: TextOverflow.ellipsis),
        );
      }).toList(),
    );
  }
}

// --- 装修状态下拉菜单 ---
class FurnishingSelector extends StatelessWidget {
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;

  const FurnishingSelector(
      {super.key,
      required this.value,
      required this.options,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Furnishing Status',
            style: TextStyle(color: Colors.white70, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: DropdownButton<String>(
            value: value,
            dropdownColor: const Color(0xFF295a68),
            isExpanded: true,
            underline: const SizedBox(),
            style: const TextStyle(color: Colors.white),
            items: options.map((option) {
              return DropdownMenuItem<String>(
                value: option,
                child: Text(option, style: const TextStyle(color: Colors.white)),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

// --- 日期选择器 ---
class PropertyDatePicker extends StatelessWidget {
  final DateTime? selectedDate;
  final VoidCallback onTap;

  const PropertyDatePicker({super.key, this.selectedDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Available Date',
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon:
              const Icon(Icons.calendar_today, color: Colors.white70),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
        ),
        child: Text(
          selectedDate == null
              ? 'Select Date'
              : DateFormat('dd/MM/yyyy').format(selectedDate!),
          style: TextStyle(
              color: selectedDate == null ? Colors.white70 : Colors.white,
              fontSize: 16),
        ),
      ),
    );
  }
}

// --- 数字输入项 (点击弹窗) ---
class NumericFeatureItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final int value;
  final VoidCallback onTap;

  const NumericFeatureItem({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 14))),
            Text(value.toString(),
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16)),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Colors.white70, size: 22),
          ],
        ),
      ),
    );
  }
}

// --- 复选框列表项 ---
class CheckboxListItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const CheckboxListItem({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        leading: Icon(icon, color: Colors.white, size: 20),
        title:
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
        trailing: Checkbox(
          value: isSelected,
          onChanged: (v) => onTap(), // onTap 会处理 setState
          activeColor: Colors.white,
          checkColor: const Color(0xFF1D5DC7),
        ),
        onTap: onTap,
      ),
    );
  }
}

// --- 合同选项 (Upload/Generate) ---
class ContractChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Function(bool) onSelected;

  const ContractChoiceChip({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = selected
        ? const Color(0xFF1D5DC7).withOpacity(0.5)
        : Colors.white.withOpacity(0.2);
    final Color contentColor = Colors.white;
    final Border border = selected
        ? Border.all(color: Colors.white, width: 1.5)
        : Border.all(color: Colors.white.withOpacity(0.3));

    return GestureDetector(
      onTap: () => onSelected(true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: border,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: contentColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                      color: contentColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- 合同上传 UI ---
class ContractUploadUI extends StatelessWidget {
  final VoidCallback onTap;
  const ContractUploadUI({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: GestureDetector(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Contract (Optional PDF)',
            labelStyle: const TextStyle(color: Colors.white70),
            prefixIcon:
                const Icon(Icons.description_outlined, color: Colors.white70),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.5))),
          ),
          child: const Text('Tap to select PDF file',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
        ),
      ),
    );
  }
}

// --- 合同生成 UI ---
class ContractGenerateUI extends StatelessWidget {
  final bool isLoading;
  final String language;
  final ValueChanged<String?> onLanguageChanged;
  final VoidCallback onGenerate;

  const ContractGenerateUI(
      {super.key,
      required this.isLoading,
      required this.language,
      required this.onLanguageChanged,
      required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: language,
                  dropdownColor: const Color(0xFF295a68),
                  style: const TextStyle(color: Colors.white),
                  icon: const Icon(Icons.language, color: Colors.white70),
                  items: const [
                    DropdownMenuItem(value: 'zh', child: Text('中文')),
                    DropdownMenuItem(value: 'en', child: Text('English')),
                  ],
                  onChanged: onLanguageChanged,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: isLoading ? null : onGenerate,
              icon: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_stories, size: 18),
              label: Text(isLoading ? 'Generating...' : 'Generate'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D5DC7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 主信息卡片 (私有 Widget) ---
class MainInfoForm extends StatelessWidget {
  final List<String> communityList;
  final String? selectedCommunity;
  final bool isCommunityListLoading;
  final TextEditingController floorController;
  final TextEditingController unitController;
  final TextEditingController descriptionController;
  final TextEditingController priceController;
  final TextEditingController sizeController;
  final DateTime? selectedDate;
  final String selectedFurnishing;
  final List<String> furnishingOptions;
  final ValueChanged<String?> onCommunityChanged;
  final VoidCallback onDateTap;
  final ValueChanged<String?> onFurnishingChanged;

  const MainInfoForm({
    super.key,
    required this.communityList,
    this.selectedCommunity,
    required this.isCommunityListLoading,
    required this.floorController,
    required this.unitController,
    required this.descriptionController,
    required this.priceController,
    required this.sizeController,
    this.selectedDate,
    required this.selectedFurnishing,
    required this.furnishingOptions,
    required this.onCommunityChanged,
    required this.onDateTap,
    required this.onFurnishingChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CommunityDropdown(
          value: selectedCommunity,
          isLoading: isCommunityListLoading,
          items: communityList,
          onChanged: onCommunityChanged,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: PropertyTextFormField(
                controller: floorController,
                labelText: 'Floor Level',
                icon: Icons.stairs_outlined,
                keyboardType: TextInputType.text,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PropertyTextFormField(
                controller: unitController,
                labelText: 'Unit / Room No.',
                icon: Icons.meeting_room_outlined,
                keyboardType: TextInputType.text,
                validator: (value) =>
                    (value == null || value.isEmpty) ? 'Please enter unit' : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FurnishingSelector(
          value: selectedFurnishing,
          options: furnishingOptions,
          onChanged: onFurnishingChanged,
        ),
        const SizedBox(height: 16),
        PropertyTextFormField(
            controller: descriptionController,
            labelText: 'More Description',
            icon: Icons.description_outlined,
            maxLines: 3),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: PropertyDatePicker(
              selectedDate: selectedDate,
              onTap: onDateTap,
            )),
            const SizedBox(width: 16),
            Expanded(
                child: PropertyTextFormField(
                    controller: priceController,
                    labelText: 'Price(RM)',
                    icon: Icons.attach_money,
                    keyboardType: TextInputType.number)),
          ],
        ),
        const SizedBox(height: 12),
        PropertyTextFormField(
            controller: sizeController,
            labelText: 'Size (sqft)',
            icon: Icons.square_foot,
            keyboardType: TextInputType.number),
      ],
    );
  }
}

// --- 特性卡片 (私有 Widget) ---
class PropertyFeaturesForm extends StatelessWidget {
  final int airConditioners, bedrooms, bathrooms, parking;
  final Map<String, IconData> featureOptions;
  final Set<String> selectedFeatures;
  // ✅ 【已修复】: 回调类型已更正
  final void Function(String, int, void Function(int)) onShowSlider;
  final Function(int) onUpdateAirConditioners;
  final Function(int) onUpdateBedrooms;
  final Function(int) onUpdateBathrooms;
  final Function(int) onUpdateParking;
  final Function(String) onToggleFeature;

  const PropertyFeaturesForm({
    super.key,
    required this.airConditioners,
    required this.bedrooms,
    required this.bathrooms,
    required this.parking,
    required this.featureOptions,
    required this.selectedFeatures,
    required this.onShowSlider,
    required this.onToggleFeature,
    required this.onUpdateAirConditioners,
    required this.onUpdateBedrooms,
    required this.onUpdateBathrooms,
    required this.onUpdateParking,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Property Features',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Column(
          children: [
            NumericFeatureItem(
              label: 'Air Conditioner',
              icon: Icons.ac_unit,
              value: airConditioners,
              onTap: () => onShowSlider(
                  'Air Conditioner', airConditioners, onUpdateAirConditioners),
            ),
            const SizedBox(height: 8),
            NumericFeatureItem(
              label: 'Bedroom',
              icon: Icons.king_bed_outlined,
              value: bedrooms,
              onTap: () =>
                  onShowSlider('Bedroom', bedrooms, onUpdateBedrooms),
            ),
            const SizedBox(height: 8),
            NumericFeatureItem(
              label: 'Bathroom',
              icon: Icons.bathtub_outlined,
              value: bathrooms,
              onTap: () =>
                  onShowSlider('Bathroom', bathrooms, onUpdateBathrooms),
            ),
            const SizedBox(height: 8),
            NumericFeatureItem(
              label: 'Car Park',
              icon: Icons.local_parking_outlined,
              value: parking,
              onTap: () =>
                  onShowSlider('Car Park', parking, onUpdateParking),
            ),
            const Divider(color: Colors.white30, height: 24),
            ...featureOptions.entries.map((e) {
              final key = e.key;
              if (key.toLowerCase().contains('air')) {
                return const SizedBox.shrink();
              }
              final isSelected = selectedFeatures.contains(key);
              return CheckboxListItem(
                label: key,
                icon: e.value,
                isSelected: isSelected,
                onTap: () => onToggleFeature(key),
              );
            }).toList(),
          ],
        ),
      ],
    );
  }
}

// --- 设施卡片 (私有 Widget) ---
class FacilitiesForm extends StatelessWidget {
  final Map<String, IconData> facilityOptions;
  final Set<String> selectedFacilities;
  final Function(String) onToggle;

  const FacilitiesForm({
    super.key,
    required this.facilityOptions,
    required this.selectedFacilities,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Facilities',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Column(
          children: facilityOptions.entries.map((entry) {
            final key = entry.key;
            final icon = entry.value;
            final isSelected = selectedFacilities.contains(key);
            return CheckboxListItem(
              label: key,
              icon: icon,
              isSelected: isSelected,
              onTap: () => onToggle(key),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// --- 合同卡片 (私有 Widget) ---
class ContractPicker extends StatelessWidget {
  final bool isLoading;
  final ContractOption contractOption;
  final File? selectedContract;
  final String? selectedContractName;
  final String generatedContractLanguage;
  final ValueChanged<ContractOption> onOptionSelected;
  final ValueChanged<String?> onLanguageChanged;
  final VoidCallback onPickContract;
  final VoidCallback onGenerateContract;
  final VoidCallback onClearContract;

  const ContractPicker({
    super.key,
    required this.isLoading,
    required this.contractOption,
    this.selectedContract,
    this.selectedContractName,
    required this.generatedContractLanguage,
    required this.onOptionSelected,
    required this.onLanguageChanged,
    required this.onPickContract,
    required this.onGenerateContract,
    required this.onClearContract,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Contract Option',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ContractChoiceChip(
                label: 'Upload Existing',
                icon: Icons.upload_file,
                selected: contractOption == ContractOption.upload,
                onSelected: (v) => onOptionSelected(ContractOption.upload),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ContractChoiceChip(
                label: 'Generate New',
                icon: Icons.auto_stories,
                selected: contractOption == ContractOption.generate,
                onSelected: (v) => onOptionSelected(ContractOption.generate),
              ),
            ),
          ],
        ),
        AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Column(
              children: [
                if (contractOption == ContractOption.upload)
                  ContractUploadUI(onTap: onPickContract),
                if (contractOption == ContractOption.generate)
                  ContractGenerateUI(
                    isLoading: isLoading,
                    language: generatedContractLanguage,
                    onLanguageChanged: onLanguageChanged,
                    onGenerate: onGenerateContract,
                  ),
              ],
            )),
        if (selectedContract != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3))),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.greenAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      selectedContractName ?? 'File Selected',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white70, size: 20),
                    onPressed: onClearContract,
                  )
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// --- 图片选择器 (私有 Widget) ---
class ImagePickerWidget extends StatelessWidget {
  final List<XFile> selectedImages;
  final VoidCallback onTap;

  const ImagePickerWidget({super.key, required this.selectedImages, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: selectedImages.isEmpty
            ? const Center(
                child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      color: Colors.white70, size: 40),
                  SizedBox(height: 8),
                  Text('Add Pictures',
                      style: TextStyle(color: Colors.white70)),
                ],
              ))
            : Padding(
                padding: const EdgeInsets.all(8.0),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedImages.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10.0),
                        child: Image.file(
                          File(selectedImages[index].path),
                          fit: BoxFit.cover,
                          width: 134,
                          height: 134,
                        ),
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}
