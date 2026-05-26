"""
Simulacion fisica de las trayectorias del Enemy en Knights Action.

Lee las constantes fisicas del enemy.gd y el layout del world.tscn,
y calcula para cada par (start_pos, target_platform) si el salto parabolico
es fisicamente posible, donde aterriza, y si choca con esquinas laterales.

Sirve para validar la IA del enemy sin necesidad de ejecutar Godot.

Ejecutar:
    python tests/sims/enemy_jump_sim.py

Si los resultados aqui no coinciden con lo que se ve jugando, hay un bug
en el codigo Godot (probablemente en la deteccion de raycasts o el orden
de operaciones).
"""

from __future__ import annotations
from dataclasses import dataclass
from typing import Optional

# ============================================================
# CONSTANTES FISICAS (deben matchear enemy.gd y player.gd)
# ============================================================

# Salto del enemy.
JUMP_VELOCITY = -850.0          # Y velocity al iniciar salto (negativa = arriba)
SPEED = 400.0                   # velocity.x horizontal al moverse

# Gravity efectiva: ProjectSettings default (980) * GRAVITY_MULTIPLIER (2.5).
GRAVITY = 980.0 * 2.5           # 2450 px/s^2

# Triggers del salto reactivo.
JUMP_TRIGGER_HEIGHT_DIFF = 40.0
JUMP_TRIGGER_MAX_DISTANCE = 250.0

# Ceiling check.
CEILING_CHECK_DISTANCE = 100.0
CEILING_CHECK_SIDE_OFFSET = 80.0

# Multi-hop.
MAX_JUMP_HEIGHT = 145.0
MAX_JUMP_HEIGHT_STRICT = MAX_JUMP_HEIGHT * 0.95   # 137.75

# Body shape del enemy (CollisionShape position(0,-30) size(20,60)).
# Y_node = Y_bottom_global. Body extiende de Y_node-60 (top) a Y_node (bottom).
BODY_HEIGHT = 60.0
BODY_WIDTH = 20.0

# Frame timing (Godot default 60 fps).
DELTA = 1.0 / 60.0


# ============================================================
# WORLD LAYOUT (debe matchear world.tscn)
# ============================================================

@dataclass
class Platform:
    name: str
    center_x: float
    center_y: float
    width: float
    height: float
    in_group: bool = True

    @property
    def x_min(self) -> float:
        return self.center_x - self.width / 2

    @property
    def x_max(self) -> float:
        return self.center_x + self.width / 2

    @property
    def y_top(self) -> float:
        return self.center_y - self.height / 2

    @property
    def y_bottom(self) -> float:
        return self.center_y + self.height / 2


PLATFORMS = [
    Platform("Floor",     0,    20, 2400, 40, in_group=False),  # NO en grupo platform
    Platform("Platform1", -300, -120, 200, 20),
    Platform("Platform2", 0,    -200, 200, 20),
    Platform("Platform3", 350,  -180, 200, 20),
]


# ============================================================
# FISICA DEL SALTO
# ============================================================

def y_position(t: float, y_initial: float) -> float:
    """Y_node en funcion del tiempo desde el inicio del salto (vel.x ignorada)."""
    return y_initial + JUMP_VELOCITY * t + 0.5 * GRAVITY * t * t


def x_position(t: float, x_initial: float, vel_x: float) -> float:
    """
    X_node en funcion del tiempo desde el inicio del salto.
    Primer frame tiene vel.x = 0, luego vel.x constante.
    """
    if t <= DELTA:
        return x_initial
    return x_initial + vel_x * (t - DELTA)


def jump_peak_height() -> float:
    """Altura maxima alcanzable (positiva)."""
    return JUMP_VELOCITY * JUMP_VELOCITY / (2.0 * GRAVITY)


def time_to_reach_y(target_y: float, y_initial: float) -> tuple[Optional[float], Optional[float]]:
    """
    Tiempos t (subiendo, bajando) donde el body bottom (Y_node) llega a target_y.
    Devuelve (None, None) si no alcanza target_y.
    """
    # y_initial + v*t + 0.5*g*t^2 = target_y
    # 0.5*g*t^2 + v*t + (y_initial - target_y) = 0
    a = 0.5 * GRAVITY
    b = JUMP_VELOCITY
    c = y_initial - target_y
    disc = b * b - 4.0 * a * c
    if disc < 0:
        return None, None
    sqrt_d = disc ** 0.5
    t_up = (-b - sqrt_d) / (2.0 * a)
    t_down = (-b + sqrt_d) / (2.0 * a)
    return t_up, t_down


# ============================================================
# DETECCION DE COLISIONES EN TRAYECTORIA
# ============================================================

def body_y_range(y_node: float) -> tuple[float, float]:
    """Devuelve (y_top, y_bottom) del shape del enemy."""
    return y_node - BODY_HEIGHT, y_node


def body_x_range(x_node: float) -> tuple[float, float]:
    return x_node - BODY_WIDTH / 2, x_node + BODY_WIDTH / 2


def rectangles_overlap(
    a_x: tuple[float, float], a_y: tuple[float, float],
    b_x: tuple[float, float], b_y: tuple[float, float]
) -> bool:
    return not (a_x[1] < b_x[0] or a_x[0] > b_x[1] or
                a_y[1] < b_y[0] or a_y[0] > b_y[1])


def simulate_trajectory(
    x_start: float, y_start: float,
    target_x: float,
    direction_sign: int,
    max_t: float = 2.0,
    step: float = 0.005,
) -> dict:
    """
    Simula la trayectoria parabolica del enemy y reporta:
    - Si choca con alguna plataforma DESDE EL LADO (no aterriza, choca).
    - Si aterriza en alguna plataforma (top desde arriba).
    - Posicion final de aterrizaje (x, y, platform_name).

    direction_sign: -1 (vel.x negativa, target izquierda) o +1.
    """
    vel_x = direction_sign * SPEED
    last_y = y_start
    last_x = x_start

    t = 0.0
    while t < max_t:
        t += step
        y = y_position(t, y_start)
        x = x_position(t, x_start, vel_x)

        body_x = body_x_range(x)
        body_y = body_y_range(y)

        # Chequear colision con CADA plataforma.
        for plat in PLATFORMS:
            plat_x = (plat.x_min, plat.x_max)
            plat_y = (plat.y_top, plat.y_bottom)
            if not rectangles_overlap(body_x, body_y, plat_x, plat_y):
                continue

            # Hay colision. Determinar tipo:
            # - Aterrizaje en top: body bottom acaba de cruzar el top desde arriba (estaba arriba y ahora dentro).
            # - Choque lateral: body cruza el lado.
            # Heuristica simple: si en el frame anterior body bottom estaba ARRIBA del top, y ahora dentro, es aterrizaje.
            prev_body_bottom = last_y
            if prev_body_bottom < plat.y_top and body_y[1] >= plat.y_top:
                # Aterrizaje (transicion desde arriba del top).
                return {
                    "outcome": "landing",
                    "platform": plat.name,
                    "x_landing": x,
                    "y_landing": plat.y_top,
                    "t": t,
                }
            else:
                # Choque (lateral o desde abajo).
                where = "side"
                if last_y > plat.y_top and y_position(t - step, y_start) > plat.y_top:
                    # Estaba debajo subiendo, choca con bottom.
                    where = "bottom"
                return {
                    "outcome": "collision",
                    "platform": plat.name,
                    "where": where,
                    "x_collision": x,
                    "y_collision": y,
                    "t": t,
                }

        last_y = y
        last_x = x

    return {
        "outcome": "no_landing",
        "x_final": last_x,
        "y_final": last_y,
        "t": t,
    }


# ============================================================
# CHECKS DE ESTADO DE LA IA
# ============================================================

def has_ceiling_above(x_enemy: float, y_enemy: float) -> bool:
    """Replica _has_ceiling_above del enemy.gd. 3 raycasts verticales en x +- offset."""
    head_y = y_enemy - 55.0
    end_y = head_y - CEILING_CHECK_DISTANCE
    offsets = [0.0, -CEILING_CHECK_SIDE_OFFSET, CEILING_CHECK_SIDE_OFFSET]

    for off in offsets:
        ray_x = x_enemy + off
        for plat in PLATFORMS:
            if plat.x_min <= ray_x <= plat.x_max:
                # Raycast vertical desde head_y hacia end_y (Y decreciente).
                # Si plat.y_top o plat.y_bottom esta entre [end_y, head_y], intersecta.
                if end_y <= plat.y_top <= head_y or end_y <= plat.y_bottom <= head_y:
                    return True
                # O el raycast empieza adentro del shape (head_y dentro).
                if plat.y_top <= head_y <= plat.y_bottom:
                    return True
    return False


def find_intermediate_platform(
    enemy_pos: tuple[float, float],
    target_pos: tuple[float, float],
) -> Optional[Platform]:
    """Replica _find_intermediate_platform del enemy.gd."""
    enemy_x, enemy_y = enemy_pos
    target_x, target_y = target_pos
    best: Optional[Platform] = None
    best_cost = float("inf")
    for plat in PLATFORMS:
        if not plat.in_group:
            continue
        plat_dy_above = enemy_y - plat.center_y
        if plat_dy_above < 40.0 or plat_dy_above > MAX_JUMP_HEIGHT:
            continue
        if plat.center_y < target_y - 30.0:
            continue
        jump_to_target = plat.center_y - target_y
        if jump_to_target > MAX_JUMP_HEIGHT * 1.1:
            continue
        # Filtro 4: descartar la plataforma donde el target probablemente está parado.
        if jump_to_target < 30.0:
            continue
        dx_e = plat.center_x - enemy_x
        dy_e = plat.center_y - enemy_y
        dx_t = target_x - plat.center_x
        dy_t = target_y - plat.center_y
        cost = (dx_e ** 2 + dy_e ** 2) ** 0.5 + (dx_t ** 2 + dy_t ** 2) ** 0.5
        if cost < best_cost:
            best_cost = cost
            best = plat
    return best


def get_effective_target(
    enemy_pos: tuple[float, float],
    target_pos: tuple[float, float],
) -> tuple[float, float]:
    """Replica _get_effective_target_position."""
    enemy_y = enemy_pos[1]
    target_y = target_pos[1]
    dy_above = enemy_y - target_y
    if dy_above <= MAX_JUMP_HEIGHT * 0.95:
        return target_pos
    intermediate = find_intermediate_platform(enemy_pos, target_pos)
    if intermediate is not None:
        return (intermediate.center_x, intermediate.center_y)
    return target_pos


def can_jump_now(
    enemy_pos: tuple[float, float],
    effective_target: tuple[float, float],
) -> tuple[bool, str]:
    """Replica _try_reactive_jump conditions. Devuelve (puede_saltar, razon)."""
    eff_x, eff_y = effective_target
    dx = abs(eff_x - enemy_pos[0])
    if dx > JUMP_TRIGGER_MAX_DISTANCE:
        return False, f"dx={dx:.1f} > {JUMP_TRIGGER_MAX_DISTANCE}"
    dy = enemy_pos[1] - eff_y
    if dy < JUMP_TRIGGER_HEIGHT_DIFF:
        return False, f"dy={dy:.1f} < {JUMP_TRIGGER_HEIGHT_DIFF}"
    if dy > MAX_JUMP_HEIGHT * 1.05:
        return False, f"dy={dy:.1f} > MAX_JUMP_HEIGHT*1.05 (físicamente imposible)"
    if has_ceiling_above(*enemy_pos):
        return False, "has_ceiling_above"
    return True, "OK"


# ============================================================
# CASOS DE TEST
# ============================================================

def print_case(title: str):
    print()
    print("=" * 70)
    print(title)
    print("=" * 70)


def test_jump_from_to(
    label: str,
    x_enemy: float,
    y_enemy: float,
    player_pos: tuple[float, float],
):
    enemy_pos = (x_enemy, y_enemy)
    effective = get_effective_target(enemy_pos, player_pos)
    can_jump, reason = can_jump_now(enemy_pos, effective)
    dx_eff = effective[0] - x_enemy
    direction_sign = 1 if dx_eff > 0 else -1 if dx_eff < 0 else 1

    print(f"\n[{label}]")
    print(f"  Enemy: ({x_enemy:.0f}, {y_enemy:.0f})  Player: {player_pos}")
    print(f"  Effective target: {effective}")
    print(f"  has_ceiling_above: {has_ceiling_above(x_enemy, y_enemy)}")
    print(f"  Can jump now: {can_jump} ({reason})")

    if can_jump:
        result = simulate_trajectory(x_enemy, y_enemy, effective[0], direction_sign)
        if result["outcome"] == "landing":
            print(f"  -> ATERRIZA en {result['platform']} a x={result['x_landing']:.1f}, t={result['t']:.3f}s")
        elif result["outcome"] == "collision":
            print(f"  -> CHOCA con {result['platform']} ({result['where']}) a ({result['x_collision']:.1f}, {result['y_collision']:.1f}), t={result['t']:.3f}s")
        else:
            print(f"  -> NO ATERRIZA en {result['t']:.3f}s: final ({result['x_final']:.1f}, {result['y_final']:.1f})")
    else:
        print(f"  -> NO salta. Camina hacia effective={effective[0]:.1f}.")


def main():
    print("=" * 70)
    print("SIMULACION DE TRAYECTORIAS DEL ENEMY")
    print("=" * 70)
    print(f"JUMP_VELOCITY = {JUMP_VELOCITY}")
    print(f"GRAVITY (efectiva) = {GRAVITY}")
    print(f"Altura max del salto = {jump_peak_height():.2f} px")
    print(f"SPEED = {SPEED}")
    print(f"JUMP_TRIGGER_MAX_DISTANCE = {JUMP_TRIGGER_MAX_DISTANCE}")
    print(f"CEILING_CHECK_SIDE_OFFSET = {CEILING_CHECK_SIDE_OFFSET}")
    print(f"MAX_JUMP_HEIGHT (multi-hop threshold) = {MAX_JUMP_HEIGHT}")

    print()
    print("Plataformas:")
    for p in PLATFORMS:
        print(f"  {p.name:10s} x=[{p.x_min:.0f}, {p.x_max:.0f}] y=[{p.y_top:.0f}, {p.y_bottom:.0f}] {'(en grupo)' if p.in_group else ''}")

    print_case("CASO 1: Enemy en suelo, player en Platform1 (mismo lado)")
    test_jump_from_to("enemy x=-100, player en Platform1", -100, 0, (-300, -130))
    test_jump_from_to("enemy x=-50, player en Platform1", -50, 0, (-300, -130))

    print_case("CASO 2: Enemy en suelo, player en Platform2 (necesita multi-hop)")
    test_jump_from_to("enemy x=300 (spawn), player en Platform2", 300, 0, (0, -210))
    test_jump_from_to("enemy x=100, player en Platform2", 100, 0, (0, -210))
    test_jump_from_to("enemy x=-50, player en Platform2", -50, 0, (0, -210))
    test_jump_from_to("enemy x=-100, player en Platform2", -100, 0, (0, -210))

    print_case("CASO 3: Enemy en Platform1, player en Platform2 (continuacion multi-hop)")
    test_jump_from_to("enemy x=-300 (centro Plat1), player en Platform2", -300, -130, (0, -210))
    test_jump_from_to("enemy x=-200 (borde Plat1), player en Platform2", -200, -130, (0, -210))

    print_case("CASO 4: Enemy en Platform1, player en suelo (target abajo)")
    test_jump_from_to("enemy x=-300, player en suelo x=0", -300, -130, (0, 0))

    print_case("CASO 5: Enemy en Platform2, player en suelo")
    test_jump_from_to("enemy x=0 (centro Plat2), player en suelo x=0", 0, -210, (0, 0))


if __name__ == "__main__":
    main()
