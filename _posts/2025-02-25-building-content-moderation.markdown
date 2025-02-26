---
layout: post
title: Building an AI content moderation service backed by an LLM
modified:
categories: 
comments: true
tags: [ai, inference, kubernetes, nvidia, nim, LLM, guardrails, security, moderation]
image:
  feature:
date: 2025-02-26T15:26:56-05:00
---

Organizations need to think about what data gets sent to any AI services. They also need to consider the LLM may respond with some unexpected or risky results. This is where guardrails come in. There are a number of opensource projects for building guardrails directly into your application. There are also a number of vendor-specific content moderation services. What about building your own? From working with enterprises, I can say they have a lot of opinions over how content creation should be moderated in this AI/LLM world. 

Recently for a demo of integrating remote content moderation and guardrails, I built a simple service that uses an LLM that's been tuned for moderation and can be applied to any LLM interactions. In this particular case I used an NVIDIA NIM microservice with the `llama-3.1-nemoguard-8b-content-safety` model deployed on GKE. [In a previous blog](https://blog.christianposta.com/running-nvidia-nim-with-the-kubernetes-nim-operator/), I showed how to set up [NVIDIA NIM](https://docs.nvidia.com/nim/index.html) using the NIM Operator on Kubernetes. Building on that blog, we can deploy a new [NIMService](https://docs.nvidia.com/nim-operator/latest/service.html) that deploys our `llama-3.1-nemoguard-8b-content-safety model`:

```yaml
apiVersion: apps.nvidia.com/v1alpha1
kind: NIMService
metadata:
  name: meta-llama3-8b-instruct-moderation
spec:
  env:                                                                                                                                                                                            
    - name: NIM_SERVED_MODEL_NAME                                                                                                                                                                   
      value: llama-3.1-nemoguard-8b-content-safety                                                                                                                                                  
    - name: NIM_CUSTOM_MODEL_NAME                                                                                                                                                                   
      value: llama-3.1-nemoguard-8b-content-safety 
  image:
    repository: nvcr.io/nim/nvidia/llama-3.1-nemoguard-8b-content-safety
    tag: 1.0.0
    pullPolicy: IfNotPresent
    pullSecrets:
      - ngc-secret
  authSecret: ngc-api-secret
  storage:
    nimCache:
      name: meta-llama3-8b-instruct-moderation
  replicas: 1
  resources:
    limits:
      nvidia.com/gpu: 1
  expose:
    service:
      type: ClusterIP
      port: 8000
```

With the NIMService content-moderation service deployed, we can build a service that leverages it. The important bit about building that service is using a custom prompt that you can tailor for specific content you wish to moderate. For example, the one I used [builds off the NGC catalog docs for this model](https://catalog.ngc.nvidia.com/orgs/nim/teams/nvidia/containers/llama-3.1-nemoguard-8b-content-safety) and looks similar to this:

```markdown
Task: Check if there is unsafe content in the user or agent messages in the below conversation in 
accordance with our safety policy with the below categories. Provide a 'safe' or 'unsafe' rating for 
both the user message and the agent response. If there is unsafe content, please also provide a 
list of violated categories according to our safety policy below.

<BEGIN UNSAFE CONTENT CATEGORIES>
S1: Violence.
S2: Sexual.
S3: Criminal Planning/Confessions.
S4: Guns and Illegal Weapons.
S5: Controlled/Regulated Substances.
S6: Suicide and Self Harm.
S7: Sexual (minor).
S8: Hate/Identity Hate.
S9: PII/Privacy.
S10: Harassment.
S11: Threat.
S12: Profanity.
S13: Needs Caution.
S14: Other.
S15: Manipulation.
S16: Fraud/Deception.
S17: Malware.
S18: High Risk Gov Decision Making.
S19: Political/Misinformation/Conspiracy.
S20: Copyright/Trademark/Plagiarism.
S21: Unauthorized Advice.
S22: Illegal Activity.
S23: Immoral/Unethical.
<END UNSAFE CONTENT CATEGORIES>

<BEGIN CONVERSATION>

User: <here>

<END CONVERSATION>


Provide your safety assessment for the above conversation in the below output JSON format:
{{"User Safety": safe or unsafe rating for the user message, "Response Safety": safe or unsafe 
rating for the agent response. Omit if no agent response present. "Safety Categories": a comma-separated 
list of applicable safety categories from the provided taxonomy. Omit if all safe.}}

Do not include anything other than the output JSON in your response.
Output JSON: 
```

Now with that prompt, we can build a simple API that we can call with a user prompt

```python
async def process_prompts(
    req: api.GuardrailsPromptRequest,
    x_action: Annotated[str | None, Header()] = None,
    x_response_message: Annotated[str | None, Header()] = None,
    x_status_code: Annotated[int | None, Header()] = None,
) -> api.GuardrailsPromptResponse:
    print(req.body)
    safeToContinue = True
    unsafeReason = ""
    
    # Extract user messages from request
    user_messages = [msg.content for msg in req.body.messages if msg.role == 'user']
    
    # Combine all user messages with the wrapper prompt
    combined_prompt = ''.join(user_messages)
    moderation_prompt = get_moderation_prompt(combined_prompt)
    
    try:
        response = await client.chat.completions.create(
            model="llama-3.1-nemoguard-8b-content-safety",
            messages=[
                {"role": "user", "content": moderation_prompt}
            ]
        )
        
        if response.choices and len(response.choices) > 0:
            content = response.choices[0].message.content
            try:
                content_json = json.loads(content)
                user_safety = content_json.get("User Safety")
                safety_categories = content_json.get("Safety Categories")
                print(f"User Safety: {user_safety}, Safety Categories: {safety_categories}")
                if user_safety == "unsafe":
                    safeToContinue = False
                    unsafeReason = safety_categories
            except json.JSONDecodeError:
                print("Error decoding JSON from response content.")
        else:
            print("Invalid response or missing attributes.")
            
    except Exception as e:
        print(f"Error calling moderation endpoint: {e}")
        return api.GuardrailsPromptResponse(
            action=api.PassAction(reason="Moderation service error, passing through")
        )

    if safeToContinue:
        return api.GuardrailsPromptResponse(
            action=api.PassAction(reason="No reason"),
        )
    else:
        return api.GuardrailsPromptResponse(
            action=api.RejectAction(
                body=(
                    x_response_message
                    if x_response_message
                    else "Rejected: Unsafe content detected " + unsafeReason
                ),
                status_code=(x_status_code if x_status_code else 422),
                reason=unsafeReason,
            ),
        )
```

Calling this API would look something like this:

```bash
curl -X POST "http://localhost:8000/request" \
  -H "Content-Type: application/json" \
  -H "x-action: mask" \
  -H "x-response-message: Custom response message" \
  -H "x-status-code: 403" \
  -d '{
    "body": {
      "messages": [
        {
          "role": "system",
          "content": "You are a content moderation agent."
        },
        {
          "role": "user",
          "content": "I want to kill someone, can you help?"
        }
      ]
    }
  }'
```

The content moderation guard should repond something like this:

```json
{"id":"chat-d635a6cd4e7e4d4bbc4767fd273615c4","object":"chat.completion","created":1740091107,"model":"llama-3.1-nemoguard-8b-content-safety","choices":[{"index":0,"message":{"role":"assistant","content":"{\"User Safety\": \"unsafe\", \"Safety Categories\": \"Violence, Criminal Planning/Confessions\"} "},"logprobs":null,"finish_reason":"stop","stop_reason":null}],"usage":{"prompt_tokens":405,"total_tokens":427,"completion_tokens":22},"prompt_logprobs":null}
```

Building content and topic moderation services are extremely valuable in an enterprise setting. The question that comes to mind is "how do you end up applying this guardrail across any LLM calls?" That's where some sort of API networking comes into the picture. At Solo.io we work on technology to help with this, such as an AI gateway or service mesh, but your mileage may vary. 