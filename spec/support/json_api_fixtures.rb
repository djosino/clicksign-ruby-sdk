# frozen_string_literal: true

module JsonApiFixtures
  BASE_URL = 'https://sandbox.clicksign.com/api/v3'

  module_function

  def template_data(id:, name:, color: '#1474f5', **attributes)
    {
      'id' => id,
      'type' => 'templates',
      'attributes' => {
        'name' => name,
        'color' => color,
        'created' => '2026-01-01T00:00:00.000-03:00',
        'modified' => '2026-01-01T00:00:00.000-03:00',
      }.merge(attributes.transform_keys(&:to_s)),
    }
  end

  def template_field_data(id:, name:, kind:, template_id:)
    {
      'id' => id,
      'type' => 'template_fields',
      'attributes' => {
        'name' => name,
        'kind' => kind,
        'created' => '2026-01-01T00:00:00.000-03:00',
        'modified' => '2026-01-01T00:00:00.000-03:00',
      },
      'relationships' => {
        'template' => {
          'data' => { 'type' => 'templates', 'id' => template_id },
        },
      },
    }
  end

  def single_resource(data)
    { 'data' => data }
  end

  def collection_resource(data)
    { 'data' => data }
  end

  def docx_content_base64
    'data:application/msword;base64,UEs='
  end

  def user_data(id:, name:, email:, phone_number: '11999999999', **attributes)
    {
      'id' => id,
      'type' => 'users',
      'attributes' => {
        'name' => name,
        'email' => email,
        'phone_number' => phone_number,
        'created' => '2026-01-01T00:00:00.000-03:00',
        'modified' => '2026-01-01T00:00:00.000-03:00',
      }.merge(attributes.transform_keys(&:to_s)),
    }
  end

  def envelope_data(id:, name:, status: 'draft', folder_id: nil,
                    remind_interval: nil, block_after_refusal: false,
                    auto_close: false, locale: 'pt-BR', metadata: nil,
                    default_subject: nil, default_message: nil, **attributes)
    base = {
      'name' => name,
      'status' => status,
      'auto_close' => auto_close,
      'locale' => locale,
      'block_after_refusal' => block_after_refusal,
      'created' => '2026-01-01T00:00:00.000-03:00',
      'modified' => '2026-01-01T00:00:00.000-03:00',
    }
    base['remind_interval']   = remind_interval   if remind_interval
    base['metadata']          = metadata          if metadata
    base['default_subject']   = default_subject   if default_subject
    base['default_message']   = default_message   if default_message

    data = {
      'id' => id,
      'type' => 'envelopes',
      'attributes' => base.merge(attributes.transform_keys(&:to_s)),
    }
    if folder_id
      data['relationships'] = {
        'folder' => { 'data' => { 'type' => 'folders', 'id' => folder_id } },
      }
    end
    data
  end

  def document_data(id:, filename:, status: 'draft', envelope_id: nil, **attributes)
    relationships = {}
    if envelope_id
      relationships['envelope'] =
        { 'data' => { 'type' => 'envelopes', 'id' => envelope_id } }
    end

    {
      'id' => id,
      'type' => 'documents',
      'attributes' => {
        'filename' => filename,
        'status' => status,
        'created' => '2026-01-01T00:00:00.000-03:00',
        'modified' => '2026-01-01T00:00:00.000-03:00',
      }.merge(attributes.transform_keys(&:to_s)),
      'relationships' => relationships,
    }
  end

  def signer_data(id:, name:, email:, envelope_id: nil, phone_number: nil,
                  birthday: nil, has_documentation: false, documentation: nil,
                  refusable: false, location_required_enabled: false,
                  communicate_events: nil, signature_host: nil, group: nil,
                  **attributes)
    relationships = {}
    if envelope_id
      relationships['envelope'] =
        { 'data' => { 'type' => 'envelopes', 'id' => envelope_id } }
    end

    base = {
      'name' => name,
      'email' => email,
      'has_documentation' => has_documentation,
      'refusable' => refusable,
      'location_required_enabled' => location_required_enabled,
      'created' => '2026-01-01T00:00:00.000-03:00',
      'modified' => '2026-01-01T00:00:00.000-03:00',
    }
    base['phone_number']       = phone_number       if phone_number
    base['birthday']           = birthday           if birthday
    base['documentation']      = documentation      if documentation
    base['communicate_events'] = communicate_events if communicate_events
    base['signature_host']     = signature_host     if signature_host
    base['group']              = group              if group

    {
      'id' => id,
      'type' => 'signers',
      'attributes' => base.merge(attributes.transform_keys(&:to_s)),
      'relationships' => relationships,
    }
  end

  def event_data(id:, name:, data: {}, envelope_id: nil, document_id: nil)
    relationships = {}
    if envelope_id
      relationships['envelope'] =
        { 'data' => { 'type' => 'envelopes', 'id' => envelope_id } }
    end
    if document_id
      relationships['document'] =
        { 'data' => { 'type' => 'documents', 'id' => document_id } }
    end

    {
      'id' => id,
      'type' => 'events',
      'attributes' => {
        'name' => name,
        'data' => data,
        'created' => '2026-01-01T00:00:00.000-03:00',
      },
      'relationships' => relationships,
    }
  end

  def webhook_data(id:, endpoint:, events:, status: 'active', **attributes)
    {
      'id' => id,
      'type' => 'webhooks',
      'attributes' => {
        'endpoint' => endpoint,
        'events' => events,
        'status' => status,
        'created' => '2026-01-01T00:00:00.000-03:00',
        'modified' => '2026-01-01T00:00:00.000-03:00',
      }.merge(attributes.transform_keys(&:to_s)),
    }
  end

  def group_data(id:, name:, **attributes)
    {
      'id' => id,
      'type' => 'groups',
      'attributes' => {
        'name' => name,
        'created' => '2026-01-01T00:00:00.000-03:00',
        'modified' => '2026-01-01T00:00:00.000-03:00',
      }.merge(attributes.transform_keys(&:to_s)),
    }
  end

  def whatsapp_data(id:, **attributes)
    {
      'id' => id,
      'type' => 'acceptance_term_whatsapps',
      'attributes' => {
        'created' => '2026-01-01T00:00:00.000-03:00',
        'modified' => '2026-01-01T00:00:00.000-03:00',
      }.merge(attributes.transform_keys(&:to_s)),
    }
  end

  def signature_watcher_data(id:, email:, kind:, envelope_id: nil,
                             attach_documents_enabled: false, **attributes)
    relationships = {}
    if envelope_id
      relationships['envelope'] =
        { 'data' => { 'type' => 'envelopes', 'id' => envelope_id } }
    end

    {
      'id' => id,
      'type' => 'signature_watchers',
      'attributes' => {
        'email' => email,
        'kind' => kind,
        'attach_documents_enabled' => attach_documents_enabled,
        'created' => '2026-01-01T00:00:00.000-03:00',
        'modified' => '2026-01-01T00:00:00.000-03:00',
      }.merge(attributes.transform_keys(&:to_s)),
      'relationships' => relationships,
    }
  end

  def folder_data(id:, name:, path: '/', in_root: true, **attributes)
    {
      'id' => id,
      'type' => 'folders',
      'attributes' => {
        'name' => name,
        'path' => path,
        'in_root' => in_root,
        'created' => '2026-01-01T00:00:00.000-03:00',
        'modified' => '2026-01-01T00:00:00.000-03:00',
      }.merge(attributes.transform_keys(&:to_s)),
    }
  end

  def requirement_data(id:, action:, envelope_id: nil, document_id: nil, signer_id: nil,
                       **attributes)
    relationships = requirement_relationships(
      envelope_id: envelope_id,
      document_id: document_id,
      signer_id: signer_id,
    )

    {
      'id' => id,
      'type' => 'requirements',
      'attributes' => {
        'action' => action,
        'created' => '2026-01-01T00:00:00.000-03:00',
        'modified' => '2026-01-01T00:00:00.000-03:00',
      }.merge(attributes.transform_keys(&:to_s)),
      'relationships' => relationships,
    }
  end

  def requirement_relationships(envelope_id:, document_id:, signer_id:)
    {}.tap do |relationships|
      if envelope_id
        relationships['envelope'] =
          { 'data' => { 'type' => 'envelopes', 'id' => envelope_id } }
      end
      if document_id
        relationships['document'] =
          { 'data' => { 'type' => 'documents', 'id' => document_id } }
      end
      if signer_id
        relationships['signer'] = { 'data' => { 'type' => 'signers', 'id' => signer_id } }
      end
    end
  end

  def envelope_bulk_creation_data(job_id:, enqueued_at: '2026-01-01T00:00:00.000-03:00')
    {
      'id' => job_id,
      'type' => 'envelope_bulk_creations',
      'attributes' => {
        'job_id' => job_id,
        'enqueued_at' => enqueued_at,
      },
    }
  end

  def membership_data(id:, role:, user_id:, consumption_accessible: false,
                      tracking_accessible: false, folder_management_accessible: false,
                      **attributes)
    {
      'id' => id,
      'type' => 'memberships',
      'attributes' => {
        'role' => role,
        'consumption_accessible' => consumption_accessible,
        'tracking_accessible' => tracking_accessible,
        'folder_management_accessible' => folder_management_accessible,
        'created' => '2026-01-01T00:00:00.000-03:00',
        'modified' => '2026-01-01T00:00:00.000-03:00',
      }.merge(attributes.transform_keys(&:to_s)),
      'relationships' => {
        'user' => { 'data' => { 'type' => 'users', 'id' => user_id } },
      },
    }
  end
end
