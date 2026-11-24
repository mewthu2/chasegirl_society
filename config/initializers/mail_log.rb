# Registra cada e-mail entregue (destinatário, assunto e ID devolvido pelo SES) para rastrear entregas.
class MailDeliveryLogger
  def self.delivered_email(message)
    Rails.logger.info("[mail] entregue para=#{Array(message.to).join(',')} assunto=#{message.subject.inspect} " \
                      "ses_id=#{message.header['ses-message-id']&.value || message.message_id}")
  end
end
ActiveSupport.on_load(:action_mailer) { register_observer(MailDeliveryLogger) }
