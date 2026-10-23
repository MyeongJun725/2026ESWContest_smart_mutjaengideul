import json
import unittest
from fast_server_atlas import parse_input, validate_home, envelope, MODEL_ID, voice_observations


class DashboardContractTest(unittest.TestCase):
    def test_passive_notice_is_only_sent_for_relevant_questions(self):
        context = json.dumps({'active_alarm': '접수된 활성 경보 없음', 'camera': '연결됨',
                              'disaster_reference': '제주도 급수 안내'})
        self.assertEqual(voice_observations(context, '우리 집에 언제 갈 수 있니?'), {})
        status = voice_observations(context, '지금 무슨 상황이야?')
        self.assertIn('active_alarm', status)
        self.assertNotIn('제주도', json.dumps(status, ensure_ascii=False))
        notice = voice_observations(context, '재난 알림은 무슨 내용이야?')
        self.assertIn('reference_notice_not_confirmed_home_emergency', notice)
    def test_screen_context_without_correction_task(self):
        body = {"model": MODEL_ID, "messages": [
            {"role": "system", "content": "ignored"},
            {"role": "user", "content": json.dumps({
                "task": "집 안 화면 상태 분석", "source": "",
                "selected_context": json.dumps({
                    "sensor": "움직임 없음", "camera": "연결 끊김",
                    "recent_dialogue": ["내일 화재 훈련입니다."]}, ensure_ascii=False)})}]}
        source, prompt, system, task = parse_input(body)
        self.assertEqual(task, "home")
        self.assertIn("움직임 없음은 부재", system)
        self.assertIn("카메라 연결 상태는 영상 분석이 아니야", system)
        self.assertIn("교정하거나 다시 출력하지 마", system)
        self.assertIn("내일 화재 훈련입니다.", prompt)

    def test_reply_has_no_caption_field(self):
        value = validate_home("내일 훈련 안내입니다. 안내된 시간을 확인해 주세요.")
        self.assertEqual(set(value), {"reply"})
        encoded = envelope(value, {}, {})['choices'][0]['message']['content']
        self.assertNotIn('caption', json.loads(encoded))

    def test_reject_malformed_and_excessive_reply(self):
        for text in ('', '```json\n{}', 'a' * 20, '상황' * 60):
            with self.assertRaises(ValueError):
                validate_home(text)

    def test_sign_contract_is_unchanged(self):
        body = {"model": MODEL_ID, "messages": [
            {"role": "system", "content": "ignored"},
            {"role": "user", "content": json.dumps({
                "task": "선택한 문맥에 맞춰 수어에 응답", "source": "아프다",
                "selected_context": ""})}]}
        source, prompt, system, task = parse_input(body)
        self.assertEqual(source, '아프다')
        self.assertFalse(task)

    def test_voice_question_uses_dialogue_prompt_with_no_device_actions(self):
        body = {"model": MODEL_ID, "messages": [
            {"role": "system", "content": "ignored"},
            {"role": "user", "content": json.dumps({
                "task": "집 안 정보로 음성 질문에 답변", "source": "무슨 상황이야?",
                "selected_context": '{"active_alarm":"초인종"}'})}]}
        source, prompt, system, task = parse_input(body)
        self.assertEqual(task, 'voice')
        self.assertIn('무슨 상황이야?', prompt)
        self.assertIn('신고·메시지 전송 기능은 없어', system)


if __name__ == '__main__':
    unittest.main()
