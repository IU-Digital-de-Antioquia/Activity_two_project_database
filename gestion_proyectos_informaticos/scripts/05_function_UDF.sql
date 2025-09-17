-- Limpieza y creación de UDF
DROP FUNCTION IF EXISTS fn_promedio_horas_por_docente;

DELIMITER $$
-- fn_promedio_horas_por_docente: Calcula el promedio de horas por proyecto para un docente dado.
-- Lógica de negocio: Ayuda a evaluar la carga laboral promedio por proyecto asignado al docente.
-- Operación matemática: AVG sobre horas; retorna 0 si no hay proyectos o datos insuficientes.
CREATE FUNCTION fn_promedio_horas_por_docente(p_docente_id INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
READS SQL DATA
BEGIN
  DECLARE v_promedio DECIMAL(10,2);
  -- Consulta promedio de horas de proyectos donde el docente es jefe
  SELECT IFNULL(AVG(horas), 0) INTO v_promedio
  FROM proyecto
  WHERE docente_id_jefe = p_docente_id;
  -- Retornar el valor, asegurando 0 en casos nulos
  RETURN v_promedio;
END$$
DELIMITER ;