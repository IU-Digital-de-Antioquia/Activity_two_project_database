DELIMITER $$
-- tr_docente_after_update: Trigger que se activa después de una actualización en docente.
-- Propósito: Registra la nueva versión en copia_actualizados_docente para auditoría histórica.
CREATE TRIGGER tr_docente_after_update
AFTER UPDATE ON docente
FOR EACH ROW
BEGIN
  -- Insertar la versión actualizada (NEW) en la tabla de auditoría; accion_fecha y usuario_sql se auto-llenan
  INSERT INTO copia_actualizados_docente
    (docente_id, numero_documento, nombres, titulo, anios_experiencia, direccion, tipo_docente)
  VALUES
    (NEW.docente_id, NEW.numero_documento, NEW.nombres, NEW.titulo, NEW.anios_experiencia, NEW.direccion, NEW.tipo_docente);
END$$

-- tr_docente_after_delete: Trigger que se activa después de una eliminación en docente.
-- Propósito: Registra la versión eliminada (OLD) en copia_eliminados_docente para recuperación o compliance.
CREATE TRIGGER tr_docente_after_delete
AFTER DELETE ON docente
FOR EACH ROW
BEGIN
  -- Insertar la versión eliminada (OLD) en la tabla de auditoría; accion_fecha y usuario_sql se auto-llenan
  INSERT INTO copia_eliminados_docente
    (docente_id, numero_documento, nombres, titulo, anios_experiencia, direccion, tipo_docente)
  VALUES
    (OLD.docente_id, OLD.numero_documento, OLD.nombres, OLD.titulo, OLD.anios_experiencia, OLD.direccion, OLD.tipo_docente);
END$$
DELIMITER ;