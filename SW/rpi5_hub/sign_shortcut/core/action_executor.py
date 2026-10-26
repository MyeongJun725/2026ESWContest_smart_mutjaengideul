from dataclasses import dataclass

from .shortcut_manager import SignShortcut


@dataclass(frozen=True)
class ActionResult:
    success: bool
    room: str
    device: str
    action: str
    power_on: bool | None
    message: str


class ActionExecutor:
    def __init__(self):
        # V1에서는 RPi5 Hub가 거실 에어컨의 논리적 전원 상태를 관리한다.
        # 실제 IoT 기기의 상태 피드백이 연결되면 이후 동기화할 수 있다.
        self._livingroom_aircon_power_on = False
        self._livingroom_curtain_open = False

    @property
    def livingroom_aircon_power_on(self) -> bool:
        return self._livingroom_aircon_power_on

    def sync_livingroom_aircon_power(self, power_on: bool) -> None:
        if type(power_on) is not bool:
            raise ValueError("power_on must be a boolean")
        self._livingroom_aircon_power_on = power_on

    def sync_livingroom_curtain_power(self, power_on: bool) -> None:
        if type(power_on) is not bool:
            raise ValueError("power_on must be a boolean")
        self._livingroom_curtain_open = power_on

    def execute(self, shortcut: SignShortcut) -> ActionResult:
        if (
            shortcut.room == "livingroom"
            and shortcut.device == "curtain"
            and shortcut.action in {"on", "off", "toggle", "stop"}
        ):
            if shortcut.action != "stop":
                self._livingroom_curtain_open = (
                    not self._livingroom_curtain_open
                    if shortcut.action == "toggle"
                    else shortcut.action == "on"
                )
            return ActionResult(
                True,
                shortcut.room,
                shortcut.device,
                shortcut.action,
                self._livingroom_curtain_open,
                "커튼 이동 명령 · 실제 위치는 미확인",
            )
        # V1 지원 기능:
        # 거실 에어컨 전원 ON/OFF Toggle
        if (
            shortcut.room == "livingroom"
            and shortcut.device == "aircon"
            and shortcut.action in {"toggle", "on", "off"}
        ):
            self._livingroom_aircon_power_on = (
                not self._livingroom_aircon_power_on
                if shortcut.action == "toggle"
                else shortcut.action == "on"
            )

            if self._livingroom_aircon_power_on:
                message = "거실 에어컨이 켜졌습니다."
            else:
                message = "거실 에어컨이 꺼졌습니다."

            return ActionResult(
                success=True,
                room=shortcut.room,
                device=shortcut.device,
                action=shortcut.action,
                power_on=self._livingroom_aircon_power_on,
                message=message,
            )

        return ActionResult(
            success=False,
            room=shortcut.room,
            device=shortcut.device,
            action=shortcut.action,
            power_on=None,
            message="아직 지원하지 않는 기기 제어 기능입니다.",
        )
