import { NextRequest, NextResponse } from "next/server";
import { getJobById } from "@/lib/query";

const JOB_ID_MAX_LEN = 64;
const JOB_ID_REGEX = /^[a-zA-Z0-9_-]+$/;

function isValidJobId(id: string): boolean {
  return id.length > 0 && id.length <= JOB_ID_MAX_LEN && JOB_ID_REGEX.test(id);
}

export async function GET(
  _request: NextRequest,
  { params }: { params: Promise<{ jobId: string }> }
) {
  try {
    const { jobId } = await params;
    if (!isValidJobId(jobId)) {
      return NextResponse.json({ error: "Invalid job ID" }, { status: 400 });
    }
    const job = await getJobById(jobId);
    if (!job) {
      return NextResponse.json({ error: "Job not found" }, { status: 404 });
    }
    return NextResponse.json(job);
  } catch (err) {
    console.error(err);
    return NextResponse.json({ error: "Something went wrong. Try again." }, { status: 500 });
  }
}
