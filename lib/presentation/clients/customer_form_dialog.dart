import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/customer/civility.dart';
import '../../domain/customer/customer.dart';
import '../app_providers.dart';
import '../theme/app_colors.dart';
import 'clients_error_messages.dart';
import 'clients_strings.dart';

Future<Customer?> showCustomerFormDialog({
  required BuildContext context,
  required WidgetRef ref,
  Customer? existing,
}) {
  return showDialog<Customer>(
    context: context,
    builder: (dialogContext) {
      return CustomerFormDialog(
        existing: existing,
        onSubmit: ({
          required Civility? civility,
          required String lastName,
          String? firstName,
          String? address,
          String? postalCode,
          String? city,
          String? email,
          String? phone,
        }) {
          final service = ref.read(customerServiceProvider);
          if (existing == null) {
            return service.create(
              civility: civility,
              lastName: lastName,
              firstName: firstName,
              address: address,
              postalCode: postalCode,
              city: city,
              email: email,
              phone: phone,
            );
          }
          return service.update(
            id: existing.id,
            civility: civility,
            lastName: lastName,
            firstName: firstName,
            address: address,
            postalCode: postalCode,
            city: city,
            email: email,
            phone: phone,
          );
        },
      );
    },
  );
}

class CustomerFormDialog extends StatefulWidget {
  const CustomerFormDialog({
    super.key,
    required this.onSubmit,
    this.existing,
  });

  final Customer? existing;
  final Future<Customer> Function({
    required Civility? civility,
    required String lastName,
    String? firstName,
    String? address,
    String? postalCode,
    String? city,
    String? email,
    String? phone,
  })
  onSubmit;

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _lastName;
  late final TextEditingController _firstName;
  late final TextEditingController _address;
  late final TextEditingController _postalCode;
  late final TextEditingController _city;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  Civility? _civility;
  String? _error;
  var _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _civility = existing?.civility;
    _lastName = TextEditingController(text: existing?.lastName ?? '');
    _firstName = TextEditingController(text: existing?.firstName ?? '');
    _address = TextEditingController(text: existing?.address ?? '');
    _postalCode = TextEditingController(text: existing?.postalCode ?? '');
    _city = TextEditingController(text: existing?.city ?? '');
    _phone = TextEditingController(text: existing?.phone ?? '');
    _email = TextEditingController(text: existing?.email ?? '');
  }

  @override
  void dispose() {
    _lastName.dispose();
    _firstName.dispose();
    _address.dispose();
    _postalCode.dispose();
    _city.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || _saving) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.onSubmit(
        civility: _civility,
        lastName: _lastName.text,
        firstName: _firstName.text,
        address: _address.text,
        postalCode: _postalCode.text,
        city: _city.text,
        email: _email.text,
        phone: _phone.text,
      );
      if (mounted) {
        Navigator.of(context).pop(saved);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = customerMutationMessage(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.existing == null ? clientsCreateTitle : clientsEditTitle,
      ),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                DropdownButtonFormField<Civility?>(
                  initialValue: _civility,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: clientsCivilityLabel,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: null,
                      child: Text(clientsCivilityNone),
                    ),
                    DropdownMenuItem(
                      value: Civility.monsieur,
                      child: Text(clientsCivilityMonsieur),
                    ),
                    DropdownMenuItem(
                      value: Civility.madame,
                      child: Text(clientsCivilityMadame),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _civility = value),
                ),
                TextFormField(
                  controller: _firstName,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: clientsFirstNameLabel,
                  ),
                ),
                TextFormField(
                  controller: _lastName,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: clientsLastNameLabel,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return clientsLastNameRequired;
                    }
                    return null;
                  },
                ),
                TextFormField(
                  controller: _address,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: clientsAddressLabel,
                  ),
                ),
                TextFormField(
                  controller: _postalCode,
                  enabled: !_saving,
                  decoration: const InputDecoration(
                    labelText: clientsPostalCodeLabel,
                  ),
                ),
                TextFormField(
                  controller: _city,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: clientsCityLabel,
                  ),
                ),
                TextFormField(
                  controller: _phone,
                  enabled: !_saving,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: clientsPhoneLabel,
                  ),
                ),
                TextFormField(
                  controller: _email,
                  enabled: !_saving,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: clientsEmailLabel,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text(clientsCancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.forest,
            foregroundColor: AppColors.onForest,
          ),
          child: const Text(clientsSaveCustomer),
        ),
      ],
    );
  }
}
